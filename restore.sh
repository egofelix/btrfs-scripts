#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/functions.sh"

# Mount backup drive?
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

