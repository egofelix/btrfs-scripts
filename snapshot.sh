#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/includes/functions.sh"

# Load Variables
VOLUMES="";
QUIET="false"; QUIETPS="";

# Scan arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -q|--quiet) QUIET="true"; QUIETPS=" &>/dev/null"; ;;
	--debug) DEBUG="true"; ;;
    -t|--target) SNAPSHOTSPATH=$(removeTrailingChar "$2" "/"); shift ;;
	-v|--volume) if [[ -z ${VOLUMES} ]]; then VOLUMES="$2"; else VOLUMES="${VOLUMES} $2"; fi; shift ;;
	-h|--help) 
	  SELFNAME=$(basename $BASH_SOURCE) 
	  echo "Usage: ${SELFNAME} [-q|--quiet] [-v|--volume <volume>] [-t|--target <targetdirectory>]";
	  echo "";
	  echo "    ${SELFNAME}";
	  echo "      Create snapshots of every mounted volume.";
	  echo "";
	  echo "    ${SELFNAME} --target /.snapshots";
	  echo "      Create snapshots of every mounted volume in \"/.snapshorts\".";
	  echo "";
	  echo "    ${SELFNAME} --volume root-data --volume usr-data";
	  echo "      Create a snapshot of volumes root-data and usr-data.";
	  echo "";
	  echo "If you ommit the <targetdirectory> then the script will try to locate it with the subvolume name @snapshots.";
	  echo "";
	  exit 0;
	  ;;
    *) echo "unknown parameter passed: ${1}."; exit 1;;
  esac
  shift
done

## Script must be started as root
if [[ "$EUID" -ne 0 ]]; then logError "Please run as root"; exit 1; fi;

# Lockfile (Only one simultan instance is allowed)
LOCKFILE="/var/lock/$(basename $BASH_SOURCE)"
source "${BASH_SOURCE%/*}/includes/lockfile.sh";

# Search snapshot volume
if isEmpty "${SNAPSHOTSPATH:-}"; then SNAPSHOTSPATH=$(LANG=C mount | grep '@snapshots' | grep -o 'on /\..* type btrfs' | awk '{print $2}'); fi;
if isEmpty "${SNAPSHOTSPATH:-}"; then logError "Cannot find snapshot directory"; exit 1; fi;

# Test if SNAPSHOTSPATH is a btrfs subvol
logDebug "SNAPSHOTSPATH: ${SNAPSHOTSPATH}";
if isEmpty $(LANG=C mount | grep "${SNAPSHOTSPATH}" | grep 'type btrfs'); then logError "Source \"${SNAPSHOTSPATH}\" must be a btrfs volume"; exit 1; fi;

# Search volumes
if isEmpty "${VOLUMES:-}"; then VOLUMES=$(LANG=C mount | grep -o -P 'subvol\=[^\s\,\)]*' | awk -F'=' '{print $2}' | sort | uniq); fi;
if isEmpty "${VOLUMES}"; then logError "Could not detect volumes to backup"; exit 1; fi;

# Test if VOLUMES are btrfs subvol's
for VOLUME in ${VOLUMES}
do
  VOLUME=$(removeLeadingChar "${VOLUME}" "/")
  if [[ -z "${VOLUME}" ]]; then continue; fi;
  if [[ "${VOLUME}" = "@"* ]]; then continue; fi;
  
  logDebug "Testing VOLUME: ${VOLUME}";
  if isEmpty $(LANG=C mount | grep -P "[\(\,](subvol\=[/]{0,1}${VOLUME})[\)\,]" | grep 'type btrfs'); then logError "Source \"${VOLUME}\" could not be found."; exit 1; fi;
done;

# Current time
STAMP=`date -u +"%Y-%m-%d_%H-%M-%S"`

# Backup
logLine "Target Directory: ${SNAPSHOTSPATH}";
for VOLUME in ${VOLUMES}
do
	VOLUME=$(removeLeadingChar "${VOLUME}" "/")
	if [[ -z "${VOLUME}" ]]; then continue; fi;
	if [[ "${VOLUME}" = "@"* ]]; then logDebug "Skipping Volume ${VOLUME}"; continue; fi;
	
	# Find the first mountpoint for the volume
	VOLUMEMOUNTPOINT=$(LANG=C mount | grep -P "[\(\,](subvol\=[/]{0,1}${VOLUME})[\)\,]" | grep -o -P 'on(\s)+[^\s]*' | awk '{print $2}' | head -1)
	
	# Create Directory for this volume
	if [[ ! -d "${SNAPSHOTSPATH}/${VOLUME}" ]]; then
		if ! runCmd mkdir -p ${SNAPSHOTSPATH}/${VOLUME}; then logError "Failed to create directory ${SNAPSHOTSPATH}/${VOLUME}."; exit 1; fi;
	fi;
	
	# Create Snapshot
	if [[ -d "${SNAPSHOTSPATH}/${VOLUME}/${STAMP}" ]]; then
	  logLine "Snapshot already exists. Aborting";
	else
	  logLine "Creating Snapshot ${SNAPSHOTSPATH}/${VOLUME}/${STAMP}"
	  if ! runCmd btrfs subvolume snapshot -r ${VOLUMEMOUNTPOINT} ${SNAPSHOTSPATH}/${VOLUME}/${STAMP}; then
		logError "Failed to create snapshot of ${SNAPSHOTSPATH}/${VOLUME}/${STAMP}";
		exit 1;
	  fi;
	fi;
done;

# Finish
sync
logLine "Snapshots done.";
