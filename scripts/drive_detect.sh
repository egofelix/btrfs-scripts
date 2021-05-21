#!/bin/bash
# Scan HDDs
HDDS=$(LANG=C fdisk -l | grep 'Disk \/dev\/' | grep -v 'loop' | awk '{print $2}' | awk -F':' '{print $1}')
HDD_COUNT=$(countLines "${HDDS}")

if [[ ${HDD_COUNT} -eq 0 ]]; then
	logLine "No drives present. Aborting"
	exit 1;
fi;

if [[ ! -z ${DRIVE_ROOT:-} ]]; then
  HDDEXISTS=$(LANG=C fdisk -l | grep 'Disk \/dev\/' | grep -v 'loop' | grep "${DRIVE_ROOT}")
  if [[ -z ${HDDEXISTS} ]]; then
    echo Drive ${DRIVE_ROOT} cannot be found.
	  exit 1;
  fi;
fi;

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
	  exit 1;
  fi;
fi;