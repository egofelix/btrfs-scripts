#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/functions.sh"

echo "Hi"
echo "$@"
echo "Your Home: ${HOME}"
echo "Bye"
exit