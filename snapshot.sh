#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/includes/functions.sh"

## Script must be started as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root";
  exit 1;
fi;

# Current time
STAMP=`date -u +"%Y-%m-%d_%H-%M-%S"`

# Search snapshot volume
SNAPDIR=$(LANG=C mount | grep '@snapshots' | grep -o 'on /\..* type btrfs' | awk '{print $2}')
if [[ -z "${SNAPDIR}" ]]; then
	logLine "Cannot find snapshot directory";
	exit;
fi;

# Search subvolumes (ignore subvolumes starting with @)
SUBVOLUMES=$(LANG=C mount | grep 'type btrfs' | grep -v -E 'subvol=[/]{0,1}@' | awk '{print $3}')
if [[ -z "${SUBVOLUMES}" ]]; then
	logLine "No subvolumes found";
	exit;
fi;

logLine "Target Directory: ${SNAPDIR}";
for subvolName in ${SUBVOLUMES}
do
	# Set SNAPNAME
	SNAPNAME="${subvolName}"
	
	if [[ "${SNAPNAME,,}" = "/var/lib/docker/"* ]]; then
		continue;
	fi;
	
	# Remove first char if it is a /
	if [[ "${SNAPNAME}" = "/"* ]]; then
		SNAPNAME="${SNAPNAME:1}"
	fi;
	
	# Replace / with -
	SNAPNAME="${SNAPNAME//[\/]/-}"
	
	# If we have an empty name, we are at the root
	if [[ -z "${SNAPNAME}" ]]; then
		SNAPNAME="root";
	fi;
	
	# Create Directory for this volume
	if [[ ! -d "${SNAPDIR}/${SNAPNAME}" ]]; then
		mkdir -p ${SNAPDIR}/${SNAPNAME};
	fi;
	
	# Create Snapshot
	logLine "Creating Snapshot ${SNAPDIR}/${SNAPNAME}/${STAMP}"
	if ! runCmd btrfs subvolume snapshot -r ${subvolName} ${SNAPDIR}/${SNAPNAME}/${STAMP}; then
		logLine "Failed!";
		exit;
	fi;
done;

# Finish
sync
logLine "Backup done.";
