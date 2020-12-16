#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/functions.sh"

# Current time
STAMP=`date -u +"%Y-%m-%d-%H-%M-%S"`

# Search snapshot volume
SNAPDIR=`LANG=C mount | grep snapshots | grep -o 'on /\..* type btrfs' | awk '{print $2}'`
if [[ -z "${SNAPDIR}" ]]; then
	logLine "Cannot find snapshot directory";
	exit;
fi;

logLine "Target Directory: ${SNAPDIR}";

# Finish
logLine "Backup done.";
