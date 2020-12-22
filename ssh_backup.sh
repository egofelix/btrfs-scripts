#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/includes/functions.sh"

# Load Variables
source "${BASH_SOURCE%/*}/includes/defaults.sh";
ACTION="send";
VOLUMES=""

# Scan arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -s|--source) SNAPSOURCE="$2"; shift ;;
    -v|--verbose) VERBOSE=""; shift ;;
	-c|--command) ACTION="$2"; shift ;;
	-vol|--volume) if [[ -z ${VOLUMES} ]]; then VOLUMES="$2"; else VOLUMES="${VOLUMES} $2"; fi; shift ;;
	-t|--target) TARGET="$2"; shift ;;
	-h|--help) 
	  SELFNAME=$(basename $BASH_SOURCE) 
	  echo "Usage: ${SELFNAME} [-s|--source <sourcevolume>] [-vol|--volume <volume>] [-t|--target <targetserver>] [-c|--command <command>]";
	  echo "";
	  echo "    Send Backups and autodetect servers:";
	  echo "      ${SELFNAME}";
	  echo "";
	  echo "    Get timestamp of latest backup for root-volume:";
	  echo "      ${SELFNAME} -c check-latest -vol root";
	  exit 0;
	  ;;
    *) echo "unknown parameter passed: ${1}."; exit 1;;
  esac
  shift
done

## Script must be started as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root";
  exit 1;
fi;

# Search snapshot volume
SNAPSOURCE=$(LANG=C mount | grep '@snapshots' | grep -o 'on /\..* type btrfs' | awk '{print $2}')
if [[ -z "${SNAPSOURCE}" ]]; then
	logLine "Cannot find snapshot directory";
	exit;
fi;

# Check if we have data in snapshot volume
VOLUMES=$(LANG=C ls ${SNAPSOURCE}/ | sort)
if [[ -z "${VOLUMES}" ]]; then
	logLine "Nothing to transfer";
	exit;
fi;

# Detect SSH-Server
source "${BASH_SOURCE%/*}/scripts/ssh_serverdetect.sh"

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
