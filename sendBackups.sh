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
	
	if [[ "${FIRSTSUBVOLUME}" == "${LASTSUBVOLUME}" ]]; then
		logLine "Only one Subvolume found!";
		#continue;
	fi;
	
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
		if [[ -d "${SNAPTARGET}/${volName}/${subvolName}" ]]; then
			logLine "Skipping backup \"${volName}_${subvolName}\" (Incremental)";
			continue;
		fi;
		
		# Copy it
		logLine "Copying backup \"${volName}_${subvolName}\" (Incremental)";
		btrfs send -p ${SNAPSOURCE}/${volName}/${PREVIOUSSUBVOLUME} ${SNAPSOURCE}/${volName}/${subvolName} | btrfs -v receive ${SNAPTARGET}/${volName}
		echo btrfs send -p ${SNAPSOURCE}/${volName}/${PREVIOUSSUBVOLUME} ${SNAPSOURCE}/${volName}/${subvolName}  btrfs -v receive ${SNAPTARGET}/${volName}
		
		# Check Result
		if [ $? -ne 0 ]; then
			logLine "Failed to copy snapshot..."
			exit;
		fi;
	done;
	
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
