#!/bin/bash
function isTrue {
	if [[ "${1^^}" = "YES" ]]; then return 0; fi;
	if [[ "${1^^}" = "TRUE" ]]; then return 0; fi;
	return 1;
}

function isFalse {
	if [[ "${1^^}" = "NO" ]]; then return 0; fi;
	if [[ "${1^^}" = "FALSE" ]]; then return 0; fi;
	return 1;
}

function logDebug {
	if isTrue "${DEBUG:-}"; then
        echo $@
	fi;
}

function logLine {
	if isTrue "true"; then
        echo $@
	fi;
}

function isEfiSystem {
	if [[ ! -d "/sys/firmware/efi" ]]; then
		return 1;
	else
		return 0;
	fi;
}

function getSystemType {
  DISTIDENTIFIER=$(uname -m)
  if [[ "${DISTIDENTIFIER^^}" = "ARMV7L" ]]; then
    echo -n "ARMHF";
  else
    echo -n "AMD64";
  fi;
}

function getSystemName {
  SYSNAME=$(uname -a)
  if [[ "${SYSNAME^^}" = *"ARCH"* ]]; then
    echo -n "ARCHLINUX";
  elif [ -f "/etc/arch-release" ]; then
    # Fallback detection
    echo -n "ARCHLINUX";
  else
    echo -n "UNKNOWN";
  fi;
}

function countLines {
  if [[ -z "$@" ]]; then
    echo -n "0";
  else
    COUNT=`echo "$@" | wc -l`;
	echo -n $COUNT;
  fi;
}

function runCmd {
  logDebug "Executing $@"

  RESULT=$($@ 2>&1)

  RESULTCODE=$?

  if [ ${RESULTCODE} -ne 0 ]; then
    logLine "Error: ${RESULT}";
	logLine "Failed Command: $@";
    return 1
  else
    return 0;
  fi;
}

function encryptPartition {
	local DEV=${1}
	local DEV=${DEV,,} # Convert to lowercase
	local PART_NAME=PART_${DEV^^} # Search variable PART_ROOT
	local PART_NAME=${!PART_NAME} # Evaluate Variable

	if isTrue "${CRYPTED}"; then
	    if [[ ! -f /tmp/crypto.key ]]; then
			logLine "Generating Crypto-KEY...";
			if ! runCmd dd if=/dev/urandom of=/tmp/crypto.key bs=1024 count=1; then echo "Failed to generate Crypto-KEY"; exit; fi;
		fi;
		
		logLine "Encrypting ${DEV^^}-Partition";
		if ! runCmd cryptsetup --batch-mode luksFormat --type luks1 -d /tmp/crypto.key ${PART_NAME}; then echo "Failed to cryptformat ${DEV^^}-Partiton"; exit; fi;
		if ! runCmd cryptsetup --batch-mode open ${PART_NAME} crypt${DEV} -d /tmp/crypto.key; then echo "Failed to open CRYPT-${DEV^^}-Partition"; exit; fi;
		
		return 0
	fi;

	return 1
}