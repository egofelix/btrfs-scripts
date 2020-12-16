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

# Detect SUBVOLUMES in backup
SUBVOLUMES=""

# Prepare drive
source "${BASH_SOURCE%/*}/prepDrive.sh"

# Finish
#logLine "Your system is ready! Type reboot to boot it.";