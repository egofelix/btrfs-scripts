#!/bin/bash
# Scan HDDs
HDDS=`LANG=C fdisk -l | grep 'Disk \/dev\/' | grep -v 'loop' | awk '{print $2}' | awk -F':' '{print $1}'`
HDD_COUNT=$(countLines "${HDDS}")

if [[ ${HDD_COUNT} -eq 0 ]]; then
	logLine "No drives present. Aborting"
	exit
fi;


if isTrue ${RAID:-}; then
	# Detect ROOT-Drive
	if [[ -z ${DRIVE_ROOT_A:-} || -z ${DRIVE_ROOT_B:-} ]]; then
		for item in $HDDS
		do
			if [[ -z "${DRIVE_ROOT_A:-}" ]]; then
				DRIVE_ROOT_A="$item"
			fi;
			if [[ -z "${DRIVE_ROOT_B:-}" ]]; then
				DRIVE_ROOT_B="$item"
			fi;
		done;
		
	  # Abort if no drive was found
	  if [[ -z "${DRIVE_ROOT_A:-}" ]]; then
		echo "No Drive found";
		exit;
	  fi;
	  
	  if [[ -z "${DRIVE_ROOT_B:-}" ]]; then
		echo "No Drive found";
		exit;
	  fi;
	fi;
else
	# Detect ROOT-Drive
	if [[ -z ${DRIVE_ROOT:-} ]]; then
	  # Assign HDDs to Partitons/Volumes
	  for item in $HDDS
	  do
		if [[ -z "${DRIVE_ROOT:-}" ]]; then
		  DRIVE_ROOT="$item"
		fi;
	  done;

	  # Abort if no drive was found
	  if [[ -z "${DRIVE_ROOT:-}" ]]; then
		echo "No Drive found";
		exit;
	  fi;
	fi;
fi;

if [[ -z ${BIOSTYPE:-} ]]; then
  if isEfiSystem; then
	BIOSTYPE="EFI";
  else
	BIOSTYPE="BIOS";
  fi;
fi;
