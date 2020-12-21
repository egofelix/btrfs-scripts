#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/functions.sh"

if [[ "$1" = "testSshReceiver" ]]; then
  echo "success"; exit 0;
fi;

if [[ "$1" = "create-volume-directory" ]]; then
  if [[ -z "$2" ]]; then
    echo "Usage: create-volume-directory name";
	exit 1;
  fi;
  
  if [[ $2 = *"." ]]; then
    echo "Illegal character . detected in name.";
	exit 1; 
  fi;
  
  # Create directory
  if !runCmd mkdir -p ${HOME}/$2; then echo "Error creating directory."; exit 1; fi;
  echo "success"; exit 0;
fi;

echo "Error";
exit 1;
