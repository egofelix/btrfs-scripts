#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/functions.sh"

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

SSH_PORT="22"
SSH_USERNAME=$(cat /proc/sys/kernel/hostname | awk -F'.' '{print $1}')

# No target?
if [[ -z "${SNAPTARGET:-}" ]]; then
  MY_HOSTNAME=$(cat /proc/sys/kernel/hostname | awk -F'.' '{print $1}')
  MY_DOMAIN=$(cat /proc/sys/kernel/hostname | cut -d'.' -f2-)
	
  RECORD_TO_CHECK="_${MY_HOSTNAME}._backup._ssh.${MY_DOMAIN}"
  DNS_RESULT=$(dig srv ${RECORD_TO_CHECK} +short)
  if [[ -z "${DNS_RESULT}" ]]; then
    RECORD_TO_CHECK="_backup._ssh.${MY_DOMAIN}"
    DNS_RESULT=$(dig srv ${RECORD_TO_CHECK} +short)
  fi;
	
  if [[ -z "${DNS_RESULT}" ]]; then
	logLine "Could not autodetect backup server. Please provide SNAPTARGET";
	exit;
  fi;

  SSH_PORT=$(echo ${DNS_RESULT} | awk '{print $3}');
  SSH_HOSTNAME=$(echo ${DNS_RESULT} | awk '{print $4}')
  SSH_HOSTNAME="${SSH_HOSTNAME::-1}"
  logLine "Autodetected Backup Server";
elif [[ ! ${SNAPTARGET} = "ssh://"* ]]; then
  logLine "Something is wrong with ${SNAPTARGET}. Aborting.";
  exit;
else 
  SSH_PART=$(echo "${SNAPTARGET}" | awk -F'/' '{print $3}')SSH_USERNAME=$(cat /proc/sys/kernel/hostname | awk -F'.' '{print $1}')

  if [[ ${SSH_PART} = *"@"* ]]; then
    SSH_USERNAME=$(echo "${SSH_PART}" | awk -F'@' '{print $1}')
    SSH_PART=$(echo "${SSH_PART}" | awk -F'@' '{print $2}')
  fi;

  if [[ ${SSH_PART} = *":"* ]]; then
    SSH_PORT=$(echo "${SSH_PART}" | awk -F':' '{print $2}')
    SSH_PART=$(echo "${SSH_PART}" | awk -F'@' '{print $1}')
  fi;

  SSH_HOSTNAME="${SSH_PART}"
  SSH_PATH=$(echo "${SNAPTARGET}" | cut -d'/' -f4-)
  SSH_PATH="/${SSH_PATH}"

fi;
	
# Test SSH

logLine "SSH-Host: ${SSH_HOSTNAME}"
logLine "SSH-Port: ${SSH_PORT}"
logLine "SSH-User: ${SSH_USERNAME}"
#logLine "SSH-Path: ${SSH_PATH}"

# Test ssh
SSH_CALL="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -o LogLevel=QUIET -p ${SSH_PORT} ${SSH_USERNAME}@${SSH_HOSTNAME}"
TESTRESULT=$(${SSH_CALL} "testSshReceiver")
if [[ $? -ne 0 ]]; then
	logLine "SSH-Connection failed.";
	logLine "${TESTRESULT}";
	exit;
fi;

# Test must return success (This identifies the backup receiver is installed and setup in authorized_keys
if [[ "${TESTRESULT}" != "success" ]]; then
	logLine "Backup receiver not installed.";
	exit;
fi;

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
