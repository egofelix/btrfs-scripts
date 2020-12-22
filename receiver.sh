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

# We must have first parameter
if [[ -z "$1" ]]; then
	echo "Missing Home dir in first paramete";
	exit 1;
fi;

function containsIllegalCharacter {
  ILLEGALCHARACTERS=("." "$" "&" "(" ")" "{" "}" "[" "]" ";" "<" ">" "\`" "|" "*" "?" "\"" "'" "*")
  for CHAR in $ILLEGALCHARACTERS;
  do
    logDebug "Testing ${CHAR}";
    if [[ "$1" = *"${CHAR}"* ]]; then return 0; fi;
  done;
  return 1;
}

echo $1
if containsIllegalCharacter "$1"; then logError "Illegal character detected in \"$1\"."; exit 1; fi;

# Update home for this script
HOME=$1
shift 1;

# Test if home is on btrfs and @ mount
MOUNTPOINT=$(findmnt -n -o SOURCE --target ${HOME})
if [[ $? -ne 0 ]] || [[ -z "${MOUNTPOINT}" ]]; then 
  echo "Could not find MOUNTPOINT for ${HOME}."; exit 1;
fi;
MOUNTDEVICE=$(echo "${MOUNTPOINT}" | awk -F'[' '{print $1}')
if [[ -z "${MOUNTDEVICE}" ]]; then 
  echo "Could not find MOUNTDEVICE for ${MOUNTPOINT}."; exit 1;
fi;
MOUNTVOLUME=$(echo "${MOUNTPOINT}" | awk -F'[' '{print $2}' | awk -F']' '{print $1}')
if [[ -z "${MOUNTVOLUME}" ]]; then 
  echo "Could not find MOUNTVOLUME for ${MOUNTPOINT}."; exit 1;
fi;
if [[ ! ${MOUNTVOLUME} = *"@"* ]]; then
  echo "Could not backup to ${HOME} as this does not lie on a @ subvolume."; exit 1;
fi;

# We must have first parameter
if [[ -z "$1" ]]; then
	echo "Missing command";
	exit 1;
fi;

# Main Commands
if [[ "$1" = "testSshReceiver" ]]; then
  echo "success"; exit 0;
fi;

# create-volume ensures that the directory exists
if [[ "$1" = "create-volume" ]]; then
  # Check Argument Count
  if [[ -z "$2" ]]; then echo "Usage: create-volume <volume>"; exit 1; fi;
 
  # Check volume parameter
  if [[ $2 = *"."* ]]; then echo "Illegal character . detected in parameter volume."; exit 1;  fi;
  
  # Create directory
  if ! runCmd mkdir -p ${HOME}/$2; then echo "Error creating volume directory."; exit 1; fi;
  echo "success"; exit 0;
fi;

# check-volume checks if a snapshot exists
if [[ "$1" = "check-volume" ]]; then
  # Check Argument Count
  if [[ -z "$2" ]] || [[ -z "$3" ]]; then echo "Usage: check-volume <volume> <name>"; exit 1; fi;
  
  # Check volume parameter
  if [[ $2 = *"."* ]]; then echo "Illegal character . detected in parameter <volume>."; exit 1;  fi;
  
  # Check name parameter
  if [[ $3 = *"."* ]]; then echo "Illegal character . detected in parameter <name>."; exit 1;  fi;
  
  # Test and return
  if [[ ! -d "${HOME}/$2/$3" ]]; then echo "false"; exit 0; fi;
  echo "true"; exit 0;
fi;

# receive-volume will receive a snapshot
if [[ "$1" = "receive-volume" ]]; then
  # Check Argument Count
  if [[ -z "$2" ]] || [[ -z "$3" ]]; then echo "Usage: receive-volume <volume> <name>"; exit 1; fi;
  
  # Check volume parameter
  if [[ $2 = *"."* ]]; then echo "Illegal character . detected in parameter <volume>."; exit 1; fi;
  
  # Check name parameter
  if [[ $3 = *"."* ]]; then echo "Illegal character . detected in parameter <name>."; exit 1; fi;

  # Check if the snapshot exists already
  if [[ -d "${HOME}/$2/$3" ]]; then echo "already exists"; exit 0; fi;
  
  # Receive  
  btrfs receive -q ${HOME}/$2 < /dev/stdin
  if [ $? -ne 0 ]; then 
    # Remove broken backup
    btrfs subvol del ${HOME}/$2/$3
	
	# Return error
    echo "receive failed";
	exit 1;
  fi;
  
  # Backup received
  echo "success"; exit 0;
fi;

if [[ "$1" = "list-volumes" ]]; then
  # Create directory
  RESULT=$(ls ${HOME})
  if [ $? -ne 0 ]; then echo "Error listing volumes."; exit 1; fi;
  exit 0;
fi;

if [[ "$1" = "list-volume" ]]; then
  # Check Argument Count
  if [[ -z "$2" ]]; then echo "Usage: list-volume volume"; exit 1; fi;
 
  # Check volume parameter
  if [[ $2 = *"."* ]]; then echo "Illegal character . detected in parameter volume."; exit 1;  fi;
  
  # Create directory
  ls ${HOME}/$2
  if [ $? -ne 0 ]; then echo "Error listing volume $2."; exit 1; fi;
  exit 0;
fi;

if [[ "$1" = "receive-volume-backup" ]]; then
  # Check Argument Count
  if [[ -z "$2" ]] || [[ -z "$3" ]]; then echo "Usage: receive-volume-backup volume backup"; exit 1; fi;
  
  # Check volume parameter
  if [[ $2 = *"."* ]]; then echo "Illegal character . detected in parameter volume."; exit 1;  fi;
  
  # Check backup parameter
  if [[ $3 = *"."* ]]; then echo "Illegal character . detected in parameter backup."; exit 1;  fi;

  # Check if backup exists
  if [[ ! -d "${HOME}/$2/$3" ]]; then echo "backup does not exists"; exit 0; fi;

  # Send Backup
  btrfs send -q ${HOME}/$2/$3
  if [ $? -ne 0 ]; then echo "Error sending volumes."; exit 1; fi;
  exit 0;
fi;

echo "Error in command $@";
exit 1;
