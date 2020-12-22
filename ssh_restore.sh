#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/includes/functions.sh"

# Load Variables
source "${BASH_SOURCE%/*}/includes/defaults.sh"

## Script must be started as root
if [[ "$EUID" -ne 0 ]]; then logError "Please run as root"; exit 1; fi;

# Install Dependencies
source "${BASH_SOURCE%/*}/scripts/dependencies.sh"
source "${BASH_SOURCE%/*}/scripts/unmount.sh"

# Scan arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -q|--quiet) QUIET="true"; QUIETPS=" &>/dev/null"; ;;
	--debug) DEBUG="true"; ;;
    -t|--target) DRIVE_ROOT=$(removeTrailingChar "$2" "/"); shift ;;
	-n|--name) HOSTNAME="$2"; shift ;;
	-h|--help) 
	  SELFNAME=$(basename $BASH_SOURCE) 
	  echo "Usage: ${SELFNAME} [-q|--quiet] [-t|--target <targetdrive>] [-n|--name <clientname>]";
	  echo "";
	  echo "    ${SELFNAME}";
	  echo "      Automatic restore.";
	  echo "";
	  echo "    ${SELFNAME} --target /dev/sdb";
	  echo "      Restore to drive /dev/sdb.";
	  echo "";
	  echo "    ${SELFNAME} --name my.host.net";
	  echo "      Use given hostname for discovery.";
	  echo "";	  
	  exit 0;
	  ;;
    *) echo "unknown parameter passed: ${1}."; exit 1;;
  esac
  shift
done

# Detect ROOT-Drive
source "${BASH_SOURCE%/*}/scripts/drive_detect.sh"

# Detect SSH-Server
source "${BASH_SOURCE%/*}/scripts/ssh_serverdetect.sh"

# query volumes
VOLUMES=$(${SSH_CALL} "list-volumes");
if [[ $? -ne 0 ]]; then logError "Unable to query volumes: ${VOLUMES}."; exit 1; fi;

# loop through volumes and list snapshots
for VOLUME in $(echo "${VOLUMES}" | sort)
do
  SNAPSHOTS=$(${SSH_CALL} "list-snapshots" "${VOLUME}");
  LASTSNAPSHOT=$(echo "${SNAPSHOTS}" | sort | tail -1);
  logDebug "Latest Snapshot for volume \"${VOLUME}\" is: ${LASTSNAPSHOT}";
done;

# Restore volumes
logDebug "Detected volumes: ${VOLUMES}";


exit 1;

# Check root volumes
SUBVOLUMES=$(${SSH_CALL} "list-volumes" | sort)
if [[ $? -ne 0 ]]; then
  logLine "Unable to query root volume.";
  logLine "${SUBVOLUMES}";
  exit 1;
fi;

# Get user confirmation
RESTOREPOINT=$(echo "${SUBVOLUMES}" | head -1)
read -p "Will restore ${RESTOREPOINT} to ${DRIVE_ROOT}. Is this ok? [Yn]: " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! $REPLY =~ ^$ ]]; then
    # TODO: Build selection here
    logLine "Script canceled by user";
    exit 1;
fi

# Prepare disk
source "${BASH_SOURCE%/*}/scripts/drive_prepare.sh"

# Create system snapshot volume
if ! runCmd btrfs subvolume create /tmp/mnt/disks/system/snapshots; then logLine "Failed to create btrfs SNAPSHOTS-Volume"; exit 1; fi;
if ! runCmd mkdir /tmp/mnt/disks/system/snapshots/root; then logLine "Failed to create snapshot directory for root."; exit 1; fi;

# Receive ROOT-Volume
logLine "Receiving ROOT-Snapshot...";
${SSH_CALL} "receive-volume-backup" "root" "${RESTOREPOINT}" | btrfs receive -q /tmp/mnt/disks/system/snapshots/root
if [[ $? -ne 0 ]]; then logLine "Failed to receive volume."; exit 1; fi;

# Restore root-data from snapshot
logLine "Restoring ROOT-Volume...";
btrfs subvol snapshot /tmp/mnt/disks/system/snapshots/root/${RESTOREPOINT} /tmp/mnt/disks/system/root-data > /dev/null
if [ $? -ne 0 ]; then logLine "Failed to restore ROOT-Volume from ROOT-Snapshot..."; exit 1; fi;

# Mount ROOT-Volume
logLine "Mounting..."
if ! runCmd mkdir -p /tmp/mnt/root; then echo "Failed to create root mount directory"; exit 1; fi;
if ! runCmd mount -o subvol=/root-data ${PART_SYSTEM} /tmp/mnt/root; then echo "Failed to Mount Subvolume ROOT-DATA at /tmp/mnt/root"; exit 1; fi;
if ! runCmd mkdir -p /tmp/mnt/root/boot; then echo "Failed to create boot directory"; exit 1; fi;
if ! runCmd mount ${PART_BOOT} /tmp/mnt/root/boot; then echo "Failed to mount BOOT-Partition"; exit 1; fi;
if ! runCmd mkdir -p /tmp/mnt/root/.snapshots; then echo "Failed to create snapshot mount point"; exit 1; fi;
if ! runCmd mount -o subvol=/snapshots ${PART_SYSTEM} /tmp/mnt/root/.snapshots; then echo "Failed to Mount Snapshot-Volume at /tmp/mnt/root/.snapshots"; exit; fi;
if isEfiSystem; then
  if ! runCmd mkdir -p /tmp/mnt/root/boot/efi; then echo "Failed to create efi directory"; exit 1; fi;
  if ! runCmd mount ${PART_EFI} /tmp/mnt/root/boot/efi; then echo "Failed to mount BOOT-Partition"; exit 1; fi;
fi;

# Now scan fstab as root is restored! (Sort so we will mount "lowest" points first!)
BTRFSMOUNTPOINTS=$(cat /tmp/mnt/root/etc/fstab | grep -e '\sbtrfs\s.*subvol\=' | awk '{print $2}' | grep -v '^\/$' | sort)
for mountpoint in ${BTRFSMOUNTPOINTS}
do
  VOLUMENAME=$(cat /tmp/mnt/root/etc/fstab | grep "${mountpoint}" | grep -o -P 'subvol\=[^\s]*' | awk -F'=' '{print $2}')
  if [[ -z ${VOLUMENAME} ]]; then
    logLine "Unable to find Volume-Name for ${mountpoint}.";
    exit 1;
  fi;

  if [[ ${VOLUMENAME} = "@"* ]]; then
    logDebug "Creating empty volume for ${mountpoint} at ${VOLUMENAME}.";
    if ! runCmd btrfs subvolume create /tmp/mnt/disks/system/${VOLUMENAME}; then echo "Failed to create btrfs ${VOLUMENAME^^}-Volume"; exit; fi;
    continue;
  fi;
	
  # Double check volume name against fstab
  VOLNAME="${mountpoint//[\/]/-}"
  VOLNAME=${VOLNAME:1}
  if [[ "${VOLNAME^^}-DATA" != "${VOLUMENAME^^}" ]]; then
    logDebug "Failed to detect volume for ${mountpoint}. Volume Name Mismacht! \"${VOLNAME^^}-DATA\" != \"${VOLUMENAME^^}\"";
    exit 1;
  fi;

  # Receive XXX-Volume
  if ! runCmd mkdir /tmp/mnt/disks/system/snapshots/${VOLNAME,,}; then logLine "Failed to create snapshot directory for ${VOLNAME,,}."; exit 1; fi;
  logLine "Receiving ${VOLNAME^^}-Snapshot...";
  ${SSH_CALL} "receive-volume-backup" "${VOLNAME,,}" "${RESTOREPOINT}" | btrfs receive -q /tmp/mnt/disks/system/snapshots/${VOLNAME,,}
  if [[ $? -ne 0 ]]; then logLine "Failed to receive volume."; exit 1; fi;
	
  # Restore XXX-data from snapshot
  logLine "Restoring ${VOLNAME^^}-Volume...";
  btrfs subvol snapshot /tmp/mnt/disks/system/snapshots/${VOLNAME,,}/${RESTOREPOINT} /tmp/mnt/disks/system/${VOLNAME,,}-data > /dev/null
  if [ $? -ne 0 ]; then logLine "Failed to restore ${VOLNAME^^}-Volume from ${VOLNAME^^}-Snapshot..."; exit 1; fi;
	
  # Mount it for later use
  if ! runCmd mount -o subvol=${VOLNAME,,}-data ${PART_SYSTEM} /tmp/mnt/root${mountpoint}; then echo "Failed to Mount Subvolume ${VOLNAME^^} at /tmp/mnt/root${mountpoint}"; exit; fi;
done;

# Message
logLine "Backups restored, finishing system restore...";

# Reinstall new crypto keys and backup header
if isTrue "${CRYPTED}"; then
  if ! runCmd cp /tmp/crypto.key /tmp/mnt/root/etc/; then logLine "Failed to copy crypto.key"; exit; fi;
  if ! runCmd cp /tmp/crypto.header /tmp/mnt/root/etc/; then logLine "Failed to copy crypto.header"; exit; fi;
fi;

# Prepare ChRoot
rm -f /tmp/mnt/root/etc/resolv.conf;
source "${BASH_SOURCE%/*}/scripts/chroot_prepare.sh";

# Reinstall Packages
source "${BASH_SOURCE%/*}/scripts/restorepackages.sh";

# Reinstall BootManager
source "${BASH_SOURCE%/*}/scripts/bootmanager.sh";

exit 0;