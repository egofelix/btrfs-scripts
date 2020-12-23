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

# Scan arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -q|--quiet) QUIET="true"; QUIETPS=" &>/dev/null"; ;;
	--debug) DEBUG="true"; ;;
    -t|--target) DRIVE_ROOT=$(removeTrailingChar "$2" "/"); shift ;;
	-n|--name) HOSTNAME="$2"; shift ;;
	-s|--snapshot) TARGETSNAPSHOT="$2"; shift ;;
	-h|--help) 
	  SELFNAME=$(basename $BASH_SOURCE) 
	  echo "Usage: ${SELFNAME} [-q|--quiet] [-t|--target <targetdrive>] [-n|--name <clientname>] [-s|--snapshot <snapshot>]";
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

# loop through volumes and list snapshots to check if which is the latest snapshot
logDebug Detected volumes: $(removeTrailingChar $(echo "${VOLUMES}" | tr '\n' ',') ',');
if [[ -z "${TARGETSNAPSHOT:-}" ]]; then
  logDebug "autodetecting latest snapshot...";
  for VOLUME in $(echo "${VOLUMES}" | sort)
  do
    SNAPSHOTS=$(${SSH_CALL} "list-snapshots" "${VOLUME}");
    LASTSNAPSHOT=$(echo "${SNAPSHOTS}" | sort | tail -1);
    logDebug "Latest Snapshot for volume \"${VOLUME}\" is: \"${LASTSNAPSHOT}\"";
	TARGETSNAPSHOT=$(echo -e "${LASTSNAPSHOT}\n${TARGETSNAPSHOT:-}" | sort | tail -1);
  done;
fi;

# Test if snapshot exists on every volume
logDebug "Snapshot to restore: ${TARGETSNAPSHOT}";
for VOLUME in $(echo "${VOLUMES}" | sort)
do
  logDebug "Checking if the snapshot exists for volume \"${VOLUME}\"...";
  SNAPSHOTS=$(${SSH_CALL} "list-snapshots" "${VOLUME}");
  SNAPSHOT=$(echo "${SNAPSHOTS}" | grep "${TARGETSNAPSHOT}");
  if [[ -z "${SNAPSHOT}" ]]; then
    logError "Cannot restore \"${TARGETSNAPSHOT}\" as volume \"${VOLUME}\" does not have this snapshot.";
	exit 1;
  fi;
done;

# Get user confirmation
read -p "Will restore ${TARGETSNAPSHOT} to ${DRIVE_ROOT}. Is this ok? [Yn]: " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! $REPLY =~ ^$ ]]; then
    # TODO: Build selection here
    logLine "Script canceled by user";
    exit 1;
fi

# Prepare disk
source "${BASH_SOURCE%/*}/scripts/unmount.sh"
source "${BASH_SOURCE%/*}/scripts/drive_prepare.sh"

# Create system snapshot volume
if ! runCmd btrfs subvolume create /tmp/mnt/disks/system/@snapshots; then logError "Failed to create btrfs @snapshots-volume"; exit 1; fi;

# Restore volumes
for VOLUME in $(echo "${VOLUMES}" | sort)
do
  logLine "Receiving snapshot for \"${VOLUME}\"...";
  if ! runCmd mkdir /tmp/mnt/disks/system/@snapshots/${VOLUME}; then logError "Failed to create snapshot directory for volume \"${VOLUME}\"."; exit 1; fi;
  ${SSH_CALL} "download-snapshot" "${VOLUME}" "${TARGETSNAPSHOT}" | btrfs receive -q /tmp/mnt/disks/system/@snapshots/${VOLUME};
  if [[ $? -ne 0 ]]; then logError "Failed to receive the snapshot for volume \"${VOLUME}\"."; exit 1; fi;
  
  # Restore ROOTVOLUME
  RESTORERESULT=$(btrfs subvol snapshot /tmp/mnt/disks/system/@snapshots/${VOLUME}/${TARGETSNAPSHOT} /tmp/mnt/disks/system/${VOLUME} 2>&1)
  if [[ $? -ne 0 ]]; then logError "Failed to restore the snapshot for volume \"${VOLUME}\": ${RESTORERESULT}."; exit 1; fi;
done;

# Scan for fstab
FSTABPATH="";
logDebug "Searching for /etc/fstab...";
for VOLUME in $(echo "${VOLUMES}" | sort)
do
  logDebug "Searching in volume \"${VOLUME}\"...";
  
  if [[ -f "/tmp/mnt/disks/system/${VOLUME}/etc/fstab" ]]; then
    if [[ ! -z "${FSTABPATH}" ]]; then
	  logError "Multiple fstab files found. Aborting.";
	  exit 1;
	fi;
	
    FSTABPATH="/tmp/mnt/disks/system/${VOLUME}/etc/fstab";
  fi;
done;
if [[ -z "${FSTABPATH}" ]]; then logError "Could not locate /etc/fstab"; exit 1; fi;
logDebug "FSTABPATH: ${FSTABPATH}";

# Create @volumes
ATVOLUMES=$(cat "${FSTABPATH}" | grep -o -P 'subvol=[\/]{0,1}@[^\s\,\)]*' | awk -F'=' '{print $2}');
for VOLUME in $(echo "${ATVOLUMES}" | sort)
do
  # Skip @snapshots as we have created it before restore
  if [[ "${VOLUME}" == "@snapshots" ]]; then continue; fi;

  # Fix for broken fstab (mount is there multiple times)
  if [[ -d "/tmp/mnt/disks/system/${VOLUME}" ]]; then continue; fi;
  
  logDebug "Creating ${VOLUME}...";
  CREATERESULT=$(btrfs subvol create /tmp/mnt/disks/system/${VOLUME} 2>&1);
  if [[ $? -ne 0 ]]; then logLine "Failed to create volume \"${VOLUME}\": ${CREATERESULT}."; exit 1; fi;
done;

# Mount
if ! runCmd mkdir -p /tmp/mnt/root; then logError "Failed to create root mountpoint"; exit 1; fi;
cat "${FSTABPATH}" | grep -v -P '^[\s]*#' | grep -v -P '^[\s]*$' | while read LINE; do
  logDebug "Handling fstab line: ${LINE}";
  LINEDEV=$(echo "$LINE" | awk '{print $1}');
  LINEMOUNT=$(echo "$LINE" | awk '{print $2}');
  LINEFS=$(echo "$LINE" | awk '{print $3}');
  LINESUBVOL=$(echo "$LINE" | awk '{print $4}' | grep -o -P 'subvol\=[^\s\,\)]*' | awk -F'=' '{print $2}');
  
  # Fix for broken fstab (mount is there multiple times, so we check if this is mounted already here)
  LINEDEVREGEX=$(echo "${LINEDEV}" | sed -e 's/[\.&]/\\&/g') # | sed -e 's/[\/&]/\\&/g')
  LINEMOUNTREGEX=$(echo "/tmp/mnt/root${LINEMOUNT}" | sed -e 's/[\.&]/\\&/g') # | sed -e 's/[\/&]/\\&/g')
  LINESUBVOLREGEX=$(echo "${LINESUBVOL}" | sed -e 's/[\.&]/\\&/g') # | sed -e 's/[\/&]/\\&/g')
  #logDebug "LINEDEVREGEX: ${LINEDEVREGEX}";
  #logDebug "LINEMOUNTREGEX: ${LINEMOUNTREGEX}";
  #logDebug "LINESUBVOLREGEX: ${LINESUBVOLREGEX}";
  #logDebug "Mounttestcmd: LANG=C mount | grep -P \"${LINEDEVREGEX}[\s]+on[\s]+${LINEMOUNTREGEX}\s.*subvol\=[/]{0,1}${LINESUBVOLREGEX}\"";
  MOUNTTEST=$(LANG=C mount | grep -P "${LINEDEVREGEX}[\s]+on[\s]+${LINEMOUNTREGEX}\s.*subvol\=[/]{0,1}${LINESUBVOLREGEX}");
  logDebug "Mounttest: ${MOUNTTEST}";
  if ! isEmpty "${MOUNTTEST}"; then
    logDebug "Skipping line, as it is mounted already (Double check)";
    continue;
  fi;
  #end
  
  
  if [[ "${LINEDEV}" == "/dev/mapper/cryptsystem" ]] || [[ "${LINEDEV}" == "LABEL=system" ]]; then
    # Mount simple volume
    logDebug "Mounting ${LINESUBVOL} at ${LINEMOUNT}...";
    MOUNTRESULT=$(mount -o "subvol=${LINESUBVOL}" /dev/mapper/cryptsystem "/tmp/mnt/root${LINEMOUNT}" 2>&1);
	if [[ $? -ne 0 ]]; then logLine "Failed to mount. Command \"mount -o \"subvol=${LINESUBVOL}\" /dev/mapper/cryptsystem \"/tmp/mnt/root${LINEMOUNT}\"\", Result \"${MOUNTRESULT}\"."; exit 1; fi;
  elif [[ "${LINEMOUNT}" == "/boot" ]]; then
    # Mount boot partition
    MOUNTRESULT=$(mount ${PART_BOOT} "/tmp/mnt/root${LINEMOUNT}" 2>&1);
	if [[ $? -ne 0 ]]; then logLine "Failed to mount: ${MOUNTRESULT}."; exit 1; fi;
  elif [[ "${LINEMOUNT}" == "/boot/efi" ]]; then
    # Mount efi partition
    if [[ -z "${PART_EFI}" ]]; then logWarn "Skipping efi partiton as we are restoring to bios"; continue; fi;
	if ! runCmd mkdir /tmp/mnt/root${LINEMOUNT}; then logError "Failed to create efi directory."; exit 1; fi;
    MOUNTRESULT=$(mount ${PART_EFI} "/tmp/mnt/root${LINEMOUNT}" 2>&1);
	if [[ $? -ne 0 ]]; then logLine "Failed to mount: ${MOUNTRESULT}."; exit 1; fi;
  elif [[ "${LINEMOUNT,,}" == "none" ]] && [[ "${LINEFS,,}" == "swap" ]]; then
    # Create swapfile
	logDebug "Creating new swapfile...";
	if ! runCmd truncate -s 0 /tmp/mnt/root${LINEMOUNT}; then logError "Failed to truncate Swap-File at /tmp/mnt/root/.swap/swapfile"; exit 1; fi;
	if ! runCmd chattr +C /tmp/mnt/root${LINEMOUNT}; then logError "Failed to chattr Swap-File at /tmp/mnt/root/.swap/swapfile"; exit 1; fi;
	if ! runCmd chmod 600 /tmp/mnt/root${LINEMOUNT}; then logError "Failed to chmod Swap-File at /tmp/mnt/root/.swap/swapfile"; exit 1; fi;
	if ! runCmd btrfs property set /tmp/mnt/root${LINEMOUNT} compression none; then logError "Failed to disable compression for Swap-File at /tmp/mnt/root/.swap/swapfile"; exit 1; fi;
	if ! runCmd fallocate /tmp/mnt/root${LINEMOUNT} -l2g; then logError "Failed to fallocate 2G Swap-File at /tmp/mnt/root/.swap/swapfile"; exit 1; fi;
	if ! runCmd mkswap /tmp/mnt/root${LINEMOUNT}; then logError "Failed to mkswap for Swap-File at /tmp/mnt/root/.swap/swapfile"; exit 1; fi;
  else
    # unknown, we skip it here
    logWarn "Skipping unknown mount ${LINEMOUNT}.";
  fi;
done;

exit 1;

# Reinstall new crypto keys and backup header
if isTrue "${CRYPTED}"; then
  logDebug "Installing new crypto key...";
  if ! runCmd cp /tmp/crypto.key /tmp/mnt/root/etc/; then logLine "Failed to copy crypto.key"; exit; fi;
  if ! runCmd cp /tmp/crypto.header /tmp/mnt/root/etc/; then logLine "Failed to copy crypto.header"; exit; fi;
fi;

# Prepare ChRoot
logDebug "Preparing chroot...";
rm -f /tmp/mnt/root/etc/resolv.conf;
source "${BASH_SOURCE%/*}/scripts/chroot_prepare.sh";

# Reinstall Packages
logDebug "Restoring packages...";
source "${BASH_SOURCE%/*}/scripts/restorepackages.sh";

# Reinstall BootManager
logDebug "Restoring Bootmanager...";
source "${BASH_SOURCE%/*}/scripts/bootmanager.sh";

# Done
sync
exit 0;