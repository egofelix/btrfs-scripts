#!/bin/bash
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