#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/includes/functions.sh"

# Load Variables
source "${BASH_SOURCE%/*}/includes/defaults.sh";
COMMAND="send";
VOLUMES="";
QUIET="false";

# Scan arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -s|--source) SNAPSOURCE=$(removeTrailingChar "$2" "/"); shift ;;
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

# PRIVATE
LOCKFILE="/var/lock/$(basename $BASH_SOURCE)"
LOCKFD=99
_lock()             { flock -$1 $LOCKFD; }
_no_more_locking()  { _lock u; _lock xn && rm -f $LOCKFILE; }
_prepare_locking()  { eval "exec $LOCKFD>\"$LOCKFILE\""; trap _no_more_locking EXIT; }
exlock_now()        { _lock xn; }  # obtain an exclusive lock immediately or fail
_prepare_locking
LOCKED=exlock_now
if ! $LOCKED; then
  logError "Script is running already";
  exit 1;
fi;

# Search snapshot volume
if isEmpty "${SNAPSOURCE:-}"; then SNAPSOURCE=$(LANG=C mount | grep '@snapshots' | grep -o 'on /\..* type btrfs' | awk '{print $2}'); fi;
if isEmpty "${SNAPSOURCE:-}"; then logError "Cannot find snapshot directory"; exit 1; fi;

# Test if SNAPSOURCE is a btrfs subvol
logDebug "SNAPSOURCE: ${SNAPSOURCE}";
if isEmpty $(mount | grep "${SNAPSOURCE}" | grep 'type btrfs'); then logError "Source \"${SNAPSOURCE}\" must be a btrfs volume"; exit 1; fi;

# Search volumes
if isEmpty "${VOLUMES:-}"; then VOLUMES=$(LANG=C ls ${SNAPSOURCE}/ | sort); fi;
if isEmpty "${VOLUMES}"; then logError "Could not detect volumes to backup"; exit 1; fi;

# Test if VOLUMES are btrfs subvol's
for VOLUME in ${VOLUMES}
do
  logDebug "Testing VOLUME: ${VOLUME}";
  if isEmpty $(mount | grep "${VOLUME}" | grep 'type btrfs'); then logError "Source \"${VOLUME}\" must be a btrfs volume"; exit 1; fi;
done;

# Detect SSH-Server
source "${BASH_SOURCE%/*}/scripts/ssh_serverdetect.sh"

# Run
if [[ "${COMMAND,,}" = "test" ]]; then logLine "Test passed"; exit 0; fi;
if [[ "${COMMAND,,}" = "check-latest" ]]; then
  for VOLUME in ${VOLUMES}; do
    logDebug "Checking volume: ${VOLUME}...";
    CHECKRESULT=$(${SSH_CALL} "list-volume" "${VOLUME}" | sort | tail -1)
	if [[ $? -ne 0 ]]; then logError "Could not check-volume \"${VOLUME}\": ${CHECKRESULT}."; exit 1; fi;
	echo "${VOLUME}: ${CHECKRESULT}";
  done

  exit 0;  
elif [[ "${COMMAND,,}" = "send" ]]; then
  logLine "Source Directory: ${SNAPSOURCE}";
  logLine "Volumes to backup: ${VOLUMES}";
  for volName in ${VOLUMES}
  do
    SUBVOLUMES=$(LANG=C ls ${SNAPSOURCE}/${volName}/)
    if [[ -z "${SUBVOLUMES}" ]]; then
       logLine "Nothing to transfer on Volume ${volName}";
       continue;
	fi;
	
	SUBVOLUMECOUNT=$(LANG=C ls ${SNAPSOURCE}/${volName}/ | sort | wc -l)
	FIRSTSUBVOLUME=$(LANG=C ls ${SNAPSOURCE}/${volName}/ | sort | head -1)
	OTHERSUBVOLUMES=$(LANG=C ls ${SNAPSOURCE}/${volName}/ | sort | tail -n +2)
	LASTSUBVOLUME=$(LANG=C ls ${SNAPSOURCE}/${volName}/ | sort | tail -1)
	
	# Create Directory for this volume
	if ! runCmd ${SSH_CALL} "create-volume-directory" "${volName}"; then echo "Failed to create volume directory at server."; exit 1; fi;
	
	# Send FIRSTSUBVOLUME
	SUBVOLUME_EXISTS=$(${SSH_CALL} check-volume-backup "${volName}" "${FIRSTSUBVOLUME}");
	if [ $? -ne 0 ]; then logLine "Failed to run ssh command: check-volume-backup "${volName}" "${FIRSTSUBVOLUME}"" exit 1; fi;
	if isFalse ${SUBVOLUME_EXISTS}; then
	  logLine "Sending backup \"${volName}_${FIRSTSUBVOLUME}\" (Full)";
	  SENDRESULT=$(btrfs send -q ${SNAPSOURCE}/${volName}/${FIRSTSUBVOLUME} | ${SSH_CALL} create-volume-backup ${volName} ${FIRSTSUBVOLUME})	
	  if [[ $? -ne 0 ]] || [[ "${SENDRESULT}" != "success" ]]; then logLine "Failed to send backup."; exit 1; fi;
	fi;
	
	PREVIOUSSUBVOLUME=${FIRSTSUBVOLUME}
	
	# Now loop over othersubvolumes
	for subvolName in ${OTHERSUBVOLUMES}
	do
	  SUBVOLUME_EXISTS=$(${SSH_CALL} check-volume-backup "${volName}" "${subvolName}");
	  if [ $? -ne 0 ]; then logLine "Failed to run ssh command: check-volume-backup "${volName}" "${FIRSTSUBVOLUME}"" exit; fi;
	  if isFalse ${SUBVOLUME_EXISTS}; then
		logLine "Sending backup \"${volName}_${subvolName}\" (Incremental)";
		SENDRESULT=$(btrfs send -q -p ${SNAPSOURCE}/${volName}/${PREVIOUSSUBVOLUME} ${SNAPSOURCE}/${volName}/${subvolName} | ${SSH_CALL} create-volume-backup ${volName} ${subvolName})	
	    if [[ $? -ne 0 ]] || [[ "${SENDRESULT}" != "success" ]]; then logLine "Failed to send backup. ${SENDRESULT}"; exit 1; fi;
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
  sync
  logLine "Backup transfer done.";
  exit 0;
else 
  logError "Unknown command \"${COMMAND}\"";
  exit 1;
fi;