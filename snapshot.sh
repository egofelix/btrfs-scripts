#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/includes/functions.sh"

# Load Variables
VOLUMES="";
QUIET="false";

# Scan arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -s|--source) SNAPSHOTSPATH=$(removeTrailingChar "$2" "/"); shift ;;
    -q|--quiet) QUIET="true"; ;;
	--debug) DEBUG="true"; ;;
	-c|--command) COMMAND="$2"; shift ;;
	-vol|--volume) if [[ -z ${VOLUMES} ]]; then VOLUMES="$2"; else VOLUMES="${VOLUMES} $2"; fi; shift ;;
	-t|--target) SSH_URI="$2"; shift ;;
	-h|--help) 
	  SELFNAME=$(basename $BASH_SOURCE) 
	  echo "Usage: ${SELFNAME} [-q|--quiet] [-s|--source <sourcevolume>] [-vol|--volume <volume>] [-t|--target <targetserver>] [-c|--command <command>]";
	  echo "";
	  echo "    ${SELFNAME}";
	  echo "      Send Backups to autodetected server.";
	  echo "";
	  echo "    ${SELFNAME} -c check-latest -vol root";
	  echo "      Get timestamp of latest backup for root-volume.";
	  echo "";
	  echo "    ${SELFNAME} -t ssh://user@server:port/";
	  echo "      Send backups to specific server.";
	  echo "";
	  echo "Supported commands are: check-latest, send, test";
	  echo "The default command is: send";
	  echo "";
	  echo "If you ommit the <targetserver> then the script will try to locate it via srv-records in dns.";
	  echo "";
	  exit 0;
	  ;;
    *) echo "unknown parameter passed: ${1}."; exit 1;;
  esac
  shift
done

## Script must be started as root
if [ "$EUID" -ne 0 ]; then logError "Please run as root"; exit 1; fi;

# Lockfile (Only one simultan instance is allowed)
LOCKFILE="/var/lock/$(basename $BASH_SOURCE)"
source "${BASH_SOURCE%/*}/includes/lockfile.sh";

# Search snapshot volume
if isEmpty "${SNAPSHOTSPATH:-}"; then SNAPSHOTSPATH=$(LANG=C mount | grep '@snapshots' | grep -o 'on /\..* type btrfs' | awk '{print $2}'); fi;
if isEmpty "${SNAPSHOTSPATH:-}"; then logError "Cannot find snapshot directory"; exit 1; fi;

# Test if SNAPSHOTSPATH is a btrfs subvol
logDebug "SNAPSHOTSPATH: ${SNAPSHOTSPATH}";
if isEmpty $(mount | grep "${SNAPSHOTSPATH}" | grep 'type btrfs'); then logError "Source \"${SNAPSHOTSPATH}\" must be a btrfs volume"; exit 1; fi;

# Search volumes
if isEmpty "${VOLUMES:-}"; then VOLUMES=$(LANG=C mount | grep -o -P 'subvol\=[^\s\,\)]*' | awk -F'=' '{print $2}' | sort | uniq); fi;
if isEmpty "${VOLUMES}"; then logError "Could not detect volumes to backup"; exit 1; fi;

# Test if VOLUMES are btrfs subvol's
for VOLUME in ${VOLUMES}
do
  VOLUME=$(removeLeadingChar "${VOLUME}" "/")
  if [[ "${VOLUME}" = "@"* ]]; then logDebug "Skipping Volume ${VOLUME}"; continue; fi;
  
  logDebug "Testing VOLUME: ${VOLUME}";
  if isEmpty $(LANG=C mount | grep -P "[\(\,](subvol\=[/]{0,1}${VOLUME})[\)\,]" | grep 'type btrfs'); then logError "Source \"${VOLUME}\" could not be found."; exit 1; fi;
done;

# Current time
STAMP=`date -u +"%Y-%m-%d_%H-%M-%S"`

# Backup
logLine "Target Directory: ${SNAPSHOTSPATH}";
exit 2;
for subvolName in ${VOLUMES}
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
	if [[ ! -d "${SNAPSHOTSPATH}/${SNAPNAME}" ]]; then
		mkdir -p ${SNAPSHOTSPATH}/${SNAPNAME};
	fi;
	
	# Create Snapshot
	logLine "Creating Snapshot ${SNAPSHOTSPATH}/${SNAPNAME}/${STAMP}"
	if ! runCmd btrfs subvolume snapshot -r /${subvolName} ${SNAPSHOTSPATH}/${SNAPNAME}/${STAMP}; then
		logError "Failed to create snapshot of ${SNAPSHOTSPATH}/${SNAPNAME}/${STAMP}";
		exit;
	fi;
done;

# Finish
sync
logLine "Backup done.";
