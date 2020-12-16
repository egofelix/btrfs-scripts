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
	
	SUBVOLUMECOUNT=$(LANG=C ls ${SNAPSOURCE}/${volName}/ | sort | wc -l)
	FIRSTSUBVOLUME=$(LANG=C ls ${SNAPSOURCE}/${volName}/ | sort | head -1)
	OTHERSUBVOLUMES=$(LANG=C ls ${SNAPSOURCE}/${volName}/ | sort | tail -n +2)
	LASTSUBVOLUME=$(LANG=C ls ${SNAPSOURCE}/${volName}/ | sort | tail -1)
	
	# Create Directory for this volume
	if [[ ! -d "${SNAPTARGET}/${volName}" ]]; then
		#logLine "Creating Directory...";
		mkdir -p ${SNAPTARGET}/${volName};
	fi;
	
	# If first subvolume does not exist send it full!
	if [[ ! -d "${SNAPTARGET}/${volName}/${FIRSTSUBVOLUME}" ]]; then
		logLine "Copying backup \"${volName}_${FIRSTSUBVOLUME}\" (NON Incremental)";
		btrfs send ${SNAPSOURCE}/${volName}/${FIRSTSUBVOLUME} | btrfs receive ${SNAPTARGET}/${volName}
	fi;
	
	PREVIOUSSUBVOLUME=${FIRSTSUBVOLUME}
	
	# Now loop over othersubvolumes
	for subvolName in ${OTHERSUBVOLUMES}
	do
		# Check if this subvolume is backuped already
		if [[ ! -d "${SNAPTARGET}/${volName}/${subvolName}" ]]; then	
			# Copy it
			logLine "Copying backup \"${volName}_${subvolName}\" (Incremental)";
			btrfs send -p ${SNAPSOURCE}/${volName}/${PREVIOUSSUBVOLUME} ${SNAPSOURCE}/${volName}/${subvolName} | btrfs receive ${SNAPTARGET}/${volName} &> /dev/null
		
			# Check Result
			if [ $? -ne 0 ]; then
				logLine "Failed to copy snapshot..."
				exit;
			fi;
		fi;
		
		# Remove previous subvolume as it is not needed here anymore!
		btrfs subvolume delete ${SNAPSOURCE}/${volName}/${PREVIOUSSUBVOLUME} &> /dev/null
		
		# Check Result
		if [ $? -ne 0 ]; then
			logLine "Failed to cleanup snapshot..."
			exit;
		fi;
		
		# Remember this subvolume as previos so we can send the next following backup as incremental
		PREVIOUSSUBVOLUME=${subvolName}
	done;
done;

# Finish
logLine "Backup transfer done.";
