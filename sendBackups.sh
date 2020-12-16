#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/functions.sh"

# Search snapshot volume
SNAPSOURCE=`LANG=C mount | grep snapshots | grep -o 'on /\..* type btrfs' | awk '{print $2}'`
if [[ -z "${SNAPSOURCE}" ]]; then
	logLine "Cannot find snapshot directory";
	exit;
fi;

SNAPTARGET=`LANG=C mount | grep -v '/dev/mapper/cryptsystem on .* type btrfs' | grep 'type btrfs' | grep -o 'on .* type btrfs' | awk '{print $2}'`
if [[ -z "${SNAPTARGET}" ]]; then
	logLine "No Backup target found";
	exit;
fi;

SUBVOLUMES=`LANG=C btrfs subvol list ${SNAPSOURCE}/ | awk '{print $9}'`
if [[ -z "${SUBVOLUMES}" ]]; then
	logLine "Nothing to transfer";
	exit;
fi;

logLine "Source Directory: ${SNAPSOURCE}";
logLine "Target Directory: ${SNAPTARGET}";
logLine "Snapshots: ${SUBVOLUMES}";
for subvolName in ${SUBVOLUMES}
do
	logLine "Copying snapshot ${subvolName}..."
	btrfs send ${SNAPSOURCE}/${subvolName} | btrfs receive -v ${SNAPTARGET}/
	
	# Check Result
	if [ $? -ne 0 ]; then
		logLine "Failed to copy snapshot..."
		
		# Cleanup possible broken snapshot
		btrfs subvol del ${SNAPTARGET}/${subvolName} &> /dev/null
		
		exit
	fi;
	
	logLine "Removing original snapshot..."
	btrfs subvol del ${SNAPSOURCE}/${subvolName}
done;

# Finish
logLine "Backup transfer done.";
