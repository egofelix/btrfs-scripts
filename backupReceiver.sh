#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/functions.sh"

if [[ "$1" = "testSshReceiver" ]]; then
  echo "success"; exit 0;
fi;

if [[ "$1" = "create-volume-directory" ]]; then
  # Check Argument Count
  if [[ -z "$2" ]]; then echo "Usage: create-volume-directory volume"; exit 1; fi;
 
  # Check volume parameter
  if [[ $2 = *"." ]]; then echo "Illegal character . detected in parameter volume."; exit 1;  fi;
  
  # Create directory
  if ! runCmd mkdir -p ${HOME}/$2; then echo "Error creating directory."; exit 1; fi;
  echo "success"; exit 0;
fi;

if [[ "$1" = "check-volume-backup" ]]; then
  # Check Argument Count
  if [ [ -z "$2" ] || [ -z "$3" ] ]; then echo "Usage: check-volume-backup volume backup"; exit 1; fi;
  
  # Check volume parameter
  if [[ $2 = *"." ]]; then echo "Illegal character . detected in parameter volume."; exit 1;  fi;
  
  # Check backup parameter
  if [[ $3 = *"." ]]; then echo "Illegal character . detected in parameter backup."; exit 1;  fi;
  
  # Test and return
  if [[ ! -d "${HOME}/$2/$3" ]]; then echo "false"; exit 1; fi;
  echo "true"; exit 0;
fi;

echo "Error";
exit 1;
