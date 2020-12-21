#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/functions.sh"

if [[ "$1" = "testSshReceiver" ]]; then
  echo "success"
  exit
fi;

if [[ "$1" = "ls" ]]; then
  ls ${HOME}
  exit
fi;


echo "Hi"
echo "$@"
echo "Your Home: ${HOME}"
echo "Bye"
exit