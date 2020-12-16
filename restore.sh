#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/functions.sh"

# Load Variables
source "${BASH_SOURCE%/*}/defaults.sh"

## Script must be started as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root";
  exit;
fi;

# Install Dependencies
source "${BASH_SOURCE%/*}/dependencies.sh"
source "${BASH_SOURCE%/*}/cleanup.sh"

# Detect ROOT-Drive
source "${BASH_SOURCE%/*}/detectRoot.sh"

# Detect BACKUP-Drive
SNAPSOURCE=$(LANG=C mount | grep -v '/dev/mapper/cryptsystem on .* type btrfs' | grep 'type btrfs' | grep -o 'on .* type btrfs' | awk '{print $2}')
if [[ -z "${SNAPSOURCE}" ]]; then
	if [[ ! -e /dev/disk/by-label/backup ]]; then
		logLine "Cannot find backup directory, please attach backup drive.";
		exit;
	fi;
	
	mkdir -p /tmp/mnt/backup;
	
	logLine "Automounting backup drive";
	mount /dev/disk/by-label/backup /tmp/mnt/backup;
	SNAPSOURCE=$(LANG=C mount | grep -v '/dev/mapper/cryptsystem on .* type btrfs' | grep 'type btrfs' | grep -o 'on .* type btrfs' | awk '{print $2}')
fi;
if [[ -z "${SNAPSOURCE}" ]]; then
	logLine "Cannot find backup directory, please attach backup drive.";
	exit;
fi;

# Check root volumes
SUBVOLUMES=$(LANG=C ls ${SNAPSOURCE}/root/)
if [[ -z "${SUBVOLUMES}" ]]; then
	logLine "No Backup for ROOT-Volume found!.";
	exit;
fi;

DRIVE_ROOT="/dev/sda";

logLine "Backup Source: ${SNAPSOURCE}";
logLine "Restore Target: ${DRIVE_ROOT}";

# Print INFO
echo
echo "System will be restored to: ${DRIVE_ROOT}"
if isTrue "${CRYPTED}"; then
	echo "The System will be encrypted with cryptsetup";
fi;
echo

# Get user confirmation
read -p "Continue? (Any data on the target drive will be ereased) [yN]: " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Script canceled by user";
    exit;   
fi

# Prepare drive
source "${BASH_SOURCE%/*}/prepDrive.sh"

# Create system snapshot volume
if ! runCmd btrfs subvolume create /tmp/mnt/disks/system/snapshots; then echo "Failed to create btrfs SNAPSHOTS-Volume"; exit; fi;
mkdir /tmp/mnt/disks/system/snapshots/root

# Restore root first
LATESTBACKUP=$(ls ${SNAPSOURCE}/root | sort | tail -1)
btrfs send ${SNAPSOURCE}/root/${LATESTBACKUP} | btrfs receive /tmp/mnt/disks/system/snapshots/root
# Check Result
if [ $? -ne 0 ]; then
	logLine "Failed to restore ROOT-Volume..."
	exit;
fi;

# Restore root-data
btrfs subvol snapshot /tmp/mnt/disks/system/snapshots/root/${LATESTBACKUP} /tmp/mnt/disks/system/root-data
# Check Result
if [ $? -ne 0 ]; then
	logLine "Failed to restore ROOT-Volume..."
	exit;
fi;

# Mount rootfs
logLine "Mounting..."
mkdir -p /tmp/mnt/root
if ! runCmd mount -o subvol=/root-data ${PART_SYSTEM} /tmp/mnt/root; then echo "Failed to Mount Subvolume ROOT-DATA at /tmp/mnt/root"; exit; fi;
mkdir -p /tmp/mnt/root/boot
if ! runCmd mount ${PART_BOOT} /tmp/mnt/root/boot; then echo "Failed to mount BOOT-Partition"; exit; fi;

mkdir -p /tmp/mnt/root/.snapshots
if ! runCmd mount -o subvol=/snapshots ${PART_SYSTEM} /tmp/mnt/root/.snapshots; then echo "Failed to Mount Snapshot-Volume at /tmp/mnt/root/.snapshots"; exit; fi;

if isEfiSystem; then
	mkdir -p /tmp/mnt/root/boot/efi
	if ! runCmd mount ${PART_EFI} /tmp/mnt/root/boot/efi; then echo "Failed to mount BOOT-Partition"; exit; fi;
fi;

# Now check fstab for additional volumes
SUBVOLUMEMOUNTPOINTS=$(cat /tmp/mnt/root/etc/fstab | grep -o 'LABEL=system.*btrfs.*subvol=.*' | awk '{print $2}' | grep -v '\/\.' | grep -v '^\/$')
for subvol in ${SUBVOLUMEMOUNTPOINTS}
do
	VOLNAME="${subvol//[\/]/-}"
	VOLNAME=${VOLNAME:1}
	SUBVOLNAME=$(cat /tmp/mnt/root/etc/fstab | grep "${subvol}" | grep -P -o 'subvol\=[^,\s\/]+' | awk -F'=' '{print $2}')
	
	logLine "Restoring ${VOLNAME} to ${SUBVOLNAME}...";
	mkdir /tmp/mnt/disks/system/snapshots/${VOLNAME}
	LATESTBACKUP=$(ls ${SNAPSOURCE}${subvol} | sort | tail -1)
	btrfs send ${SNAPSOURCE}${subvol}/${LATESTBACKUP} | btrfs receive /tmp/mnt/disks/system/snapshots/${VOLNAME}
	# Check Result
	if [ $? -ne 0 ]; then
		logLine "Failed to restore ${VOLNAME}-Volume..."
		exit;
	fi;

	# Restore data
	btrfs subvol snapshot /tmp/mnt/disks/system/snapshots/${VOLNAME}/${LATESTBACKUP} /tmp/mnt/disks/system/${SUBVOLNAME}
	# Check Result
	if [ $? -ne 0 ]; then
		logLine "Failed to restore ${VOLNAME}-Volume..."
		exit;
	fi;
	
	# Mount it for later use
	if ! runCmd mount -o subvol=/${SUBVOLNAME,,} ${PART_SYSTEM} /tmp/mnt/root/${subvol}; then echo "Failed to Mount Subvolume ${SUBVOLNAME^^} at /tmp/mnt/root/${subvol}"; exit; fi;
done;

# Do chroot and reinstall grub to fix new created /boot and /boot/efi


# Finish
#logLine "Your system is ready! Type reboot to boot it.";