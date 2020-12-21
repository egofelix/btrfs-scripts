#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/functions.sh"

echo "$SSH_ORIGINAL_COMMAND"
echo "Bye"
exit