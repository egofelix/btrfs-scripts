#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/includes/functions.sh"

# Load Variables
source "${BASH_SOURCE%/*}/includes/defaults.sh"

## Script must be started as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root";
  exit 1;
fi;

# Install Dependencies
source "${BASH_SOURCE%/*}/scripts/dependencies.sh"
source "${BASH_SOURCE%/*}/scripts/unmount.sh"

# Detect ROOT-Drive
source "${BASH_SOURCE%/*}/scripts/drive_detect.sh"

# Detect SSH-Server
source "${BASH_SOURCE%/*}/scripts/ssh_serverdetect.sh"

# Check root volumes
SUBVOLUMES=$(${SSH_CALL} "list-volume" "root" | sort -r)
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
if ! runCmd mkdir /tmp/mnt/disks/system/snapshots/root; then logLine "Failed to create root directory"; exit 1; fi;

# Receive ROOT-Volume
${SSH_CALL} "receive-volume-backup" "root" "${RESTOREPOINT}" | btrfs receive -q /tmp/mnt/disks/system/snapshots/root
if [[ $? -ne 0 ]]; then logLine "Failed to receive volume."; exit 1; fi;

exit 0;