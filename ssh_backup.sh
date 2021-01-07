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
    -q|--quiet) QUIET="true"; QUIETPS=" &>/dev/null"; ;;
	-nc|--nocrypt) CRYPTED="false"; ;;
	--debug) DEBUG="true"; ;;
	-d|--distro) DISTRO="${2^^}"; shift ;;
	-h|--help) 
	  SELFNAME=$(basename $BASH_SOURCE) 
	  echo "Usage: ${SELFNAME} [-q|--quiet] [-nc|--nocrypt] [-d|--distro <distro>]";
	  echo "";
	  echo "    ${SELFNAME}";
	  echo "      Will install encrypted arch linux.";
	  echo "";
	  echo "    ${SELFNAME} -d ubuntu";
	  echo "      Will install encrypted ubuntu.";
	  echo "";
	  echo "    ${SELFNAME} -nc -d debian.";
	  echo "      Will install unencrypted debian.";
	  echo "";
	  echo "Supported distros are: archlinux, debian, ubuntu";
	  echo "";
	  echo "If you ommit the <distro> then the script will use archlinux.";
	  echo "";
	  exit 0;
	  ;;
    *) echo "unknown parameter passed: ${1}."; exit 1;;
  esac
  shift
done

## Script must be started as root
if [[ "$EUID" -ne 0 ]]; then logError "Please run as root"; exit 1; fi;

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

# Detect SSH-Server
source "${BASH_SOURCE%/*}/scripts/ssh_serverdetect.sh"

# Test Command
if [[ "${COMMAND,,}" = "test" ]]; then logLine "Test passed"; exit 0; fi;

# Lockfile (Only one simultan instance is allowed)
LOCKFILE="/var/lock/$(basename $BASH_SOURCE)"
source "${BASH_SOURCE%/*}/includes/lockfile.sh";

# Send Command
if [[ "${COMMAND,,}" = "send" ]]; then
  logLine "Source Directory: ${SNAPSHOTSPATH}";
  for VOLUME in ${VOLUMES}; do
    # Skip @volumes
    VOLUME=$(removeLeadingChar "${VOLUME}" "/")
	if [[ -z "${VOLUME}" ]]; then continue; fi;
	if [[ "${VOLUME}" = "@"* ]]; then logDebug "Skipping Volume ${VOLUME}"; continue; fi;
	
	# Check if there are any snapshots for this volume
	SNAPSHOTS=$(LANG=C ls ${SNAPSHOTSPATH}/${VOLUME}/)
	if [[ -z "${SNAPSHOTS}" ]]; then
       logLine "No snapshots available to transfer for volume \"${VOLUME}\".";
       continue;
	fi;
	
	#SNAPSHOTCOUNT=$(LANG=C ls ${SNAPSHOTSPATH}/${VOLUME}/ | sort | wc -l)
	FIRSTSNAPSHOT=$(LANG=C ls ${SNAPSHOTSPATH}/${VOLUME}/ | sort | head -1)
	OTHERSNAPSHOTS=$(LANG=C ls ${SNAPSHOTSPATH}/${VOLUME}/ | sort | tail -n +2) # Includes last SNAPSHOT
	LASTSNAPSHOT=$(LANG=C ls ${SNAPSHOTSPATH}/${VOLUME}/ | sort | tail -1)
	logDebug "FIRSTSNAPSHOT: ${FIRSTSNAPSHOT}";
	logDebug "LASTSNAPSHOT: ${LASTSNAPSHOT}";
	logDebug OTHERSNAPSHOTS: $(removeTrailingChar $(echo "${OTHERSNAPSHOTS}" | tr '\n' ',') ',');
	
	# Create Directory for this volume on the backup server
	logDebug "Ensuring volume directory at server for \"${VOLUME}\"...";
	CREATERESULT=$(${SSH_CALL} "create-volume" "${VOLUME}");
	if [[ $? -ne 0 ]]; then logError "Command 'create-volume \"${VOLUME}\"' failed: ${CREATERESULT}."; exit 1; fi;
	
	# Send FIRSTSNAPSHOT
	CHECKVOLUMERESULT=$(${SSH_CALL} check-volume "${VOLUME}" "${FIRSTSNAPSHOT}");
	if [[ $? -ne 0 ]]; then logError "Command 'check-volume \"${VOLUME}\" \"${FIRSTSNAPSHOT}\"' failed: ${CHECKVOLUMERESULT}."; exit 1; fi;
	if isFalse ${CHECKVOLUMERESULT}; then
	  logLine "Sending snapshot \"${FIRSTSNAPSHOT}\" for volume \"${VOLUME}\"... (Full)";
	  SENDRESULT=$(btrfs send -q ${SNAPSHOTSPATH}/${VOLUME}/${FIRSTSNAPSHOT} | ${SSH_CALL} upload-snapshot "${VOLUME}" "${FIRSTSNAPSHOT}");
	  if [[ $? -ne 0 ]] || [[ "${SENDRESULT}" != "success" ]]; then logError "Command 'upload-snapshot \"${VOLUME}\" \"${FIRSTSNAPSHOT}\"' failed: ${SENDRESULT}"; exit 1; fi;
	fi;
  
    # Now loop over incremental snapshots
    PREVIOUSSNAPSHOT=${FIRSTSNAPSHOT}
    for SNAPSHOT in ${OTHERSNAPSHOTS}
    do
      CHECKVOLUMERESULT=$(${SSH_CALL} check-volume "${VOLUME}" "${SNAPSHOT}");
	  if [[ $? -ne 0 ]]; then logError "Command 'check-volume \"${VOLUME}\" \"${SNAPSHOT}\"' failed: ${CHECKVOLUMERESULT}."; exit 1; fi;
	  if isFalse ${CHECKVOLUMERESULT}; then
	    logLine "Sending snapshot \"${SNAPSHOT}\" for volume \"${VOLUME}\"... (Incremental)";
	    SENDRESULT=$(btrfs send -q -p ${SNAPSHOTSPATH}/${VOLUME}/${PREVIOUSSNAPSHOT} ${SNAPSHOTSPATH}/${VOLUME}/${SNAPSHOT} | ${SSH_CALL} upload-snapshot "${VOLUME}" "${SNAPSHOT}");
	    if [[ $? -ne 0 ]] || [[ "${SENDRESULT}" != "success" ]]; then logError "Command 'upload-snapshot \"${VOLUME}\" \"${SNAPSHOT}\"' failed: ${SENDRESULT}"; exit 1; fi;
	  fi;

	  # Remove previous subvolume as it is not needed here anymore!	  
	  logDebug "Removing SNAPSHOT \"${PREVIOUSSNAPSHOT}\"...";
	  REMOVERESULT=$(btrfs subvolume delete ${SNAPSHOTSPATH}/${VOLUME}/${PREVIOUSSNAPSHOT})
	  if [[ $? -ne 0 ]]; then logError "Failed to remove snapshot \"${SNAPSHOT}\" for volume \"${VOLUME}\": ${REMOVERESULT}."; exit 1; fi;
	  
	  # Remember this snapshot as previos so we can send the next following backup as incremental
	  PREVIOUSSNAPSHOT="${SNAPSHOT}";
    done;
  done;
	
  logLine "All snapshots has been transfered";
  sync;
  exit 0;
fi;

exit 1;

# Run

if [[ "${COMMAND,,}" = "check-latest" ]]; then
  for VOLUME in ${VOLUMES}; do
    logDebug "Checking volume: ${VOLUME}...";
    CHECKRESULT=$(${SSH_CALL} "list-volume" "${VOLUME}" | sort | tail -1)
	if [[ $? -ne 0 ]]; then logError "Could not check-volume \"${VOLUME}\": ${CHECKRESULT}."; exit 1; fi;
	echo "${VOLUME}: ${CHECKRESULT}";
  done

  exit 0;  
elif [[ "${COMMAND,,}" = "send" ]]; then
  logLine "Source Directory: ${SNAPSHOTSPATH}";
  logLine "Volumes to backup: ${VOLUMES}";
  for volName in ${VOLUMES}
  do
    SUBVOLUMES=$(LANG=C ls ${SNAPSHOTSPATH}/${volName}/)
    if [[ -z "${SUBVOLUMES}" ]]; then
       logLine "Nothing to transfer on Volume ${volName}";
       continue;
	fi;
	
	SUBVOLUMECOUNT=$(LANG=C ls ${SNAPSHOTSPATH}/${volName}/ | sort | wc -l)
	FIRSTSUBVOLUME=$(LANG=C ls ${SNAPSHOTSPATH}/${volName}/ | sort | head -1)
	OTHERSUBVOLUMES=$(LANG=C ls ${SNAPSHOTSPATH}/${volName}/ | sort | tail -n +2)
	LASTSUBVOLUME=$(LANG=C ls ${SNAPSHOTSPATH}/${volName}/ | sort | tail -1)
	
	# Create Directory for this volume
	if ! runCmd ${SSH_CALL} "create-volume-directory" "${volName}"; then echo "Failed to create volume directory at server."; exit 1; fi;
	
	# Send FIRSTSUBVOLUME
	SUBVOLUME_EXISTS=$(${SSH_CALL} check-volume-backup "${volName}" "${FIRSTSUBVOLUME}");
	if [ $? -ne 0 ]; then logLine "Failed to run ssh command: check-volume-backup "${volName}" "${FIRSTSUBVOLUME}"" exit 1; fi;
	if isFalse ${SUBVOLUME_EXISTS}; then
	  logLine "Sending backup \"${volName}_${FIRSTSUBVOLUME}\" (Full)";
	  SENDRESULT=$(btrfs send -q ${SNAPSHOTSPATH}/${volName}/${FIRSTSUBVOLUME} | ${SSH_CALL} create-volume-backup ${volName} ${FIRSTSUBVOLUME})	
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
		SENDRESULT=$(btrfs send -q -p ${SNAPSHOTSPATH}/${volName}/${PREVIOUSSUBVOLUME} ${SNAPSHOTSPATH}/${volName}/${subvolName} | ${SSH_CALL} create-volume-backup ${volName} ${subvolName})	
	    if [[ $? -ne 0 ]] || [[ "${SENDRESULT}" != "success" ]]; then logLine "Failed to send backup. ${SENDRESULT}"; exit 1; fi;
	  fi;
		
	  # Remove previous subvolume as it is not needed here anymore!
	  btrfs subvolume delete ${SNAPSHOTSPATH}/${volName}/${PREVIOUSSUBVOLUME} &> /dev/null
		
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