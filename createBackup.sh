#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/functions.sh"

# Current time
STAMP=`date -u +"%Y-%m-%d-%H-%M-%S"`

# Search snapshot volume
SNAPDIR=`LANG=C mount | grep snapshots | grep -o 'on /\..* type btrfs' | awk '{print $2}'`
if [[ -z "${SNAPDIR}" ]]; then
	logLine "Cannot find snapshot directory";
	exit;
fi;

SUBVOLUMES=`LANG=C mount | grep -o 'on .* type btrfs' | grep -v 'on \/\.snapshots' | awk '{print $2}'`
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
	if [[ -z "${SNAPNAME}" ]]; then SNAPNAME="root"; fi;
	
	SNAPNAME="${SNAPNAME}-${STAMP}"
	
	logLine "Creating Snapshot ${SNAPNAME}"
	if ! runCmd btrfs subvolume snapshot -r ${subvolName} ${SNAPDIR}/${SNAPNAME}; then
		logLine "Failed!";
		exit;
	fi;
	
	logLine "Snapshot created";
done;

# Finish
logLine "Backup done.";
