#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/functions.sh"

# Current time
STAMP=`date -u +"%Y-%m-%d_%H-%M-%S"`

# Search snapshot volume
SNAPDIR=`LANG=C mount | grep '@snapshots' | grep -o 'on /\..* type btrfs' | awk '{print $2}'`
if [[ -z "${SNAPDIR}" ]]; then
	logLine "Cannot find snapshot directory";
	exit;
fi;

# Search subvolumes (ignore subvolumes starting with @)
SUBVOLUMES=`LANG=C mount | grep 'type btrfs' | grep -v -E 'subvol=[/]{0,1}@' | awk '{print $3}'`
if [[ -z "${SUBVOLUMES}" ]]; then
	logLine "No subvolumes found";
	exit;
fi;

logLine "Target Directory: ${SNAPDIR}";
for subvolName in ${SUBVOLUMES}
do
	SNAPNAME="${subvolName//[\/]/-}"
	
	# Remove first char
	SNAPNAME="${SNAPNAME:1}"
	if [[ -z "${SNAPNAME}" ]]; then
		SNAPNAME="root";
	fi;
	
	# Create Directory for this volume
	if [[ ! -d "${SNAPDIR}/${SNAPNAME}" ]]; then
		mkdir -p ${SNAPDIR}/${SNAPNAME};
	fi;
	
	#SNAPNAME="${SNAPNAME}_${STAMP}"
	
	logLine "Creating Snapshot ${SNAPDIR}/${SNAPNAME}/${STAMP}"
	if ! runCmd btrfs subvolume snapshot -r ${subvolName} ${SNAPDIR}/${SNAPNAME}/${STAMP}; then
		logLine "Failed!";
		exit;
	fi;
done;

# Finish
sync
logLine "Backup done.";
