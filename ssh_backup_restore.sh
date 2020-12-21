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
  exit;
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
  exit;
fi;

RESTOREPOINT=$(echo "${SUBVOLUMES}" | tail -n +1)
echo ${RESTOREPOINT}

# Get user confirmation
read -p "Will restore ? (Any data on the drive will be ereased) [yN]: " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Script canceled by user";
    exit;   
fi

echo ${SUBVOLUMES}