#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/includes/functions.sh"

# Load Variables
QUIET="false"; QUIETPS="";
COMMAND=""
SNAPSHOTSPATH=""

# Scan arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -q|--quiet) QUIET="true"; QUIETPS=" &>/dev/null"; ;;
	--debug) DEBUG="true"; ;;
    -t|--target) SNAPSHOTSPATH=$(removeTrailingChar "$2" "/"); shift ;;
	-c|--command) COMMAND="$2"; shift ;;
	-h|--help) 
	  SELFNAME=$(basename $BASH_SOURCE) 
	  echo "Usage: ${SELFNAME} --target <targetdirectory> --command <command>]";
	  echo "";
	  echo "    ${SELFNAME} --target /.backups/user --command testReceiver";
	  echo "      Returns success if the receiver should be working.";
	  echo "";
	  exit 0;
	  ;;
    *) echo "unknown parameter passed: ${1}."; exit 1;;
  esac
  shift
done

# Helper function
function containsIllegalCharacter {
  local ILLEGALCHARACTERS=("." "$" "&" "(" ")" "{" "}" "[" "]" ";" "<" ">" "\`" "|" "*" "?" "\"" "'" "*" "\\" "/")
  for CHAR in "${ILLEGALCHARACTERS[@]}"
  do
    if [[ "$1" == *"${CHAR}"* ]]; then return 0; fi;
  done;
  return 1;
}

# Test if parameters has been provided
if isEmpty "${SNAPSHOTSPATH:-}"; then logError "<targetdirectory> must be provided."; exit 1; fi;
if isEmpty "${COMMAND:-}"; then logError "<command> must be provided."; exit 1; fi;

# Test if SNAPSHOTSPATH is a btrfs subvol
logDebug "SNAPSHOTSPATH: ${SNAPSHOTSPATH}";
SNAPSHOTMOUNT=$(LANG=C findmnt -n -o SOURCE --target "${SNAPSHOTSPATH}")
if [[ $? -ne 0 ]] || [[ -z "${SNAPSHOTMOUNT}" ]]; then logError "Could not find mount for \"${SNAPSHOTSPATH}\"."; exit 1; fi;
SNAPSHOTMOUNTDEVICE=$(echo "${SNAPSHOTMOUNT}" | awk -F'[' '{print $1}')
if [[ -z "${SNAPSHOTMOUNTDEVICE}" ]]; then logError "Could not find device for ${SNAPSHOTMOUNTDEVICE}."; exit 1; fi;
SNAPSHOTMOUNTVOLUME=$(echo "${SNAPSHOTMOUNT}" | awk -F'[' '{print $2}' | awk -F']' '{print $1}')
if [[ -z "${SNAPSHOTMOUNTVOLUME}" ]]; then logError "Could not find volume for ${SNAPSHOTMOUNTVOLUME}."; exit 1; fi;
if [[ ! ${SNAPSHOTMOUNTVOLUME} = "@"* ]] && [[ ! ${SNAPSHOTMOUNTVOLUME} = "/@"* ]]; then
  logWarn "The target directory relies on volume \"${SNAPSHOTMOUNTVOLUME}\" which will also be snapshotted/backupped, consider using a targetvolume with an @ name...";
fi;

# Test if command is illegal
if containsIllegalCharacter "${COMMAND}"; then logError "Illegal character detected in \"${COMMAND}\"."; exit 1; fi;
COMMAND_NAME=$(echo "${COMMAND}" | awk '{print $1}')

## Script must be started as root
if [[ "$EUID" -ne 0 ]]; then logError "Please run as root"; exit 1; fi;

# Lockfile (Only one simultan instance per SNAPSHOTSPATH is allowed)
LOCKFILE="${SNAPSHOTSPATH}/.$(basename $BASH_SOURCE)"

# Command testreceiver
if [[ "${COMMAND_NAME,,}" = "testreceiver" ]]; then
  echo "success";
  exit 0;
fi;

# Command create-volume
if [[ "${COMMAND_NAME,,}" = "create-volume" ]]; then
  # Test <volume> parameter
  VOLUME=$(echo "${COMMAND}" | awk '{print $2}');
  if [[ -z "${VOLUME}" ]]; then logError "Usage: create-volume <volume>"; exit 1; fi;

  # Aquire lock
  source "${BASH_SOURCE%/*}/includes/lockfile.sh";
  
  # Create directory
  if ! runCmd mkdir -p ${SNAPSHOTSPATH}/${VOLUME}; then logError "Failed to create volume directory."; exit 1; fi;
  echo "success"; exit 0;
fi;

# Command check-volume
if [[ "${COMMAND_NAME,,}" = "check-volume" ]]; then
  # Test <volume> and <name> parameter
  VOLUME=$(echo "${COMMAND}" | awk '{print $2}');
  NAME=$(echo "${COMMAND}" | awk '{print $3}');
  if [[ -z "${VOLUME}" ]] || [[ -z "${NAME}" ]]; then logError "Usage: check-volume <volume> <name>"; exit 1; fi;
  
  # Test and return
  if [[ ! -d "${SNAPSHOTSPATH}/${VOLUME}/${NAME}" ]]; then echo "false"; exit 0; fi;
  echo "true"; exit 0;
fi;

# Command list-volumes
if [[ "${COMMAND_NAME,,}" = "list-volumes" ]]; then
  # list directory
  RESULT=$(ls ${SNAPSHOTSPATH})
  if [[ $? -ne 0 ]]; then logError "listing volumes failed: ${RESULT}."; exit 1; fi;
  echo "${RESULT}"; exit 0;
fi;

# Command list-volume
if [[ "${COMMAND_NAME,,}" = "list-snapshots" ]]; then
  # Test <volume> parameter
  VOLUME=$(echo "${COMMAND}" | awk '{print $2}') 
  if [[ -z "${VOLUME}" ]]; then logError "Usage: list-snapshots <volume>"; exit 1; fi;
  
  # Create directory
  RESULT=$(ls ${SNAPSHOTSPATH}/${VOLUME});
  if [[ $? -ne 0 ]]; then logError "listing snapshots of volume \"${VOLUME}\" failed: ${RESULT}."; exit 1; fi;
  echo "${RESULT}"; exit 0;
fi;

# Command upload-volume
if [[ "${COMMAND_NAME,,}" = "upload-snapshot" ]]; then
  # Test <volume> and <name> parameter
  VOLUME=$(echo "${COMMAND}" | awk '{print $2}');
  NAME=$(echo "${COMMAND}" | awk '{print $3}');
  if [[ -z "${VOLUME}" ]] || [[ -z "${NAME}" ]]; then logError "Usage: upload-snapshot <volume> <name>"; exit 1; fi;
  
  # Aquire lock
  source "${BASH_SOURCE%/*}/includes/lockfile.sh";
  
  # Check if the snapshot exists already
  if [[ -d "${SNAPSHOTSPATH}/${VOLUME}/${NAME}" ]]; then logError "already exists"; exit 1; fi;
  
  # Receive
  _abortReceive() {
    REMOVERESULT=$(btrfs subvol del ${SNAPSHOTSPATH}/${VOLUME}/${NAME});
    logError "Receive Aborted: ${REMOVERESULT}";
  }
  trap _abortReceive EXIT;
  RESULT=$(LANG=C btrfs receive ${SNAPSHOTSPATH}/${VOLUME} < /dev/stdin 2>&1);
  RESULTCODE=$?
  
  # Restore Trap
  trap _no_more_locking EXIT;
  
  # Validate Receive
  if [[ ${RESULTCODE} -ne 0 ]]; then
	# Remove broken backup
	# TODO, Detect name from RESULT here, otherwise the user could maybe delete snaps from the remote
    REMOVERESULT=$(btrfs subvol del ${SNAPSHOTSPATH}/${VOLUME}/${NAME});
	
	# Return error
	logError "failed to receive the volume: ${RESULT}."; exit 1;
  fi;
  
  # Check if subvolume matches
  SUBVOLCHECK=$(echo ${RESULT} | grep 'subvol ');
  if [[ -z "${SUBVOLCHECK}" ]]; then
    # Return error
	logError "failed to detect subvolume: ${SUBVOLCHECK}."; exit 1;
  fi;
  
  if [[ "${SUBVOLCHECK}" != "./${NAME}" ]]; then
    # Return error
	logError "subvolume mismatch \"${SUBVOLCHECK}\" != \"${NAME}/\"."; exit 1;
  fi;
  
  # Snapshot received
  echo "success"; exit 0;
fi;

# Command download-volume
if [[ "${COMMAND_NAME,,}" = "download-snapshot" ]]; then
  # Test <volume> and <name> parameter
  VOLUME=$(echo "${COMMAND}" | awk '{print $2}');
  NAME=$(echo "${COMMAND}" | awk '{print $3}');
  if [[ -z "${VOLUME}" ]] || [[ -z "${NAME}" ]]; then logError "Usage: download-snapshot <volume> <name>"; exit 1; fi;

  # Check if snapshot exists
  if [[ ! -d "${SNAPSHOTSPATH}/${VOLUME}/${NAME}" ]]; then logError "snapshot does not exists"; exit 1; fi;

  # Aquire lock
  source "${BASH_SOURCE%/*}/includes/lockfile.sh";
  
  # Send Snapshot
  btrfs send -q ${SNAPSHOTSPATH}/${VOLUME}/${NAME};
  if [[ $? -ne 0 ]]; then logError "Error sending snapshot."; exit 1; fi;
  exit 0;
fi;

# Unknown command
logError "Unknown Command: ${COMMAND_NAME}.";
exit 1;
