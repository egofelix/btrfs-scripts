#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/functions.sh"

# Search snapshot volume
SNAPSOURCE=$(LANG=C mount | grep snapshots | grep -o 'on /\..* type btrfs' | awk '{print $2}')
if [[ -z "${SNAPSOURCE}" ]]; then
	logLine "Cannot find snapshot directory";
	exit;
fi;

SNAPTARGET=$(LANG=C mount | grep -v '/dev/mapper/cryptsystem on .* type btrfs' | grep 'type btrfs' | grep -o 'on .* type btrfs' | awk '{print $2}')
if [[ -z "${SNAPTARGET}" ]]; then
	logLine "No Backup target found";
	exit;
fi;

VOLUMES=$(LANG=C ls ${SNAPSOURCE}/ | sort)
if [[ -z "${VOLUMES}" ]]; then
	logLine "Nothing to transfer";
	exit;
fi;

logLine "Source Directory: ${SNAPSOURCE}";
logLine "Target Directory: ${SNAPTARGET}";
logLine "Snapshots: ${VOLUMES}";
for volName in ${VOLUMES}
do
	SUBVOLUMES=$(LANG=C ls ${SNAPSOURCE}/${volName}/)
	if [[ -z "${VOLUMES}" ]]; then
		logLine "Nothing to transfer on Volume ${volName}";
		continue;
	fi;
	
	SUBVOLUMECOUNT=$(ls /.snapshots/home/ | sort | wc -l)
	FIRSTSUBVOLUME=$(LANG=C ls ${SNAPSOURCE}/${volName}/ | sort | head -1)
	LASTSUBVOLUME=$(LANG=C ls ${SNAPSOURCE}/${volName}/ | sort | tail -1)
	OTHERSUBVOLUMES=$(LANG=C ls ${SNAPSOURCE}/${volName}/ | sort | tail -n +2 | head -n -1)
	
	if [[ "${FIRSTSUBVOLUME}" -eq "${LASTSUBVOLUME}" ]]; then
		logLine "Only one Subvolume found!";
		#continue;
	fi;
	
	# Create Directory for this volume
	if [[ ! -d "${SNAPTARGET}/${volName}" ]]; then
		#logLine "Creating Directory...";
		mkdir -p ${SNAPTARGET}/${volName};
	fi;
	
	# Full backup?
	if [[ ! -d "${SNAPTARGET}/${volName}/${FIRSTSUBVOLUME}" ]]; then
		logLine "Copying backup \"${FIRSTSUBVOLUME}\" (NON Incremental)";
		echo btrfs send ${SNAPSOURCE}/${volName}/${FIRSTSUBVOLUME} | btrfs receive -v ${SNAPTARGET}/${volName}/
	fi;
	
	#logLine "Copying snapshot ${subvolName}..."
	#btrfs send ${SNAPSOURCE}/${subvolName} | btrfs receive -v ${SNAPTARGET}/
	
	# Check Result
	#if [ $? -ne 0 ]; then
	#	logLine "Failed to copy snapshot..."
	#	
	#	# Cleanup possible broken snapshot
	#	btrfs subvol del ${SNAPTARGET}/${subvolName} &> /dev/null
	#	
	#	exit
	#fi;
	
	#logLine "Removing original snapshot..."
	#btrfs subvol del ${SNAPSOURCE}/${subvolName}
done;

# Finish
logLine "Backup transfer done.";
