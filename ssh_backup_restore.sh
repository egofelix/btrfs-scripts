#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/includes/functions.sh"

# Load Variables
source "${BASH_SOURCE%/*}/includes/defaults.sh"

## Script must be started as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root";
  exit;
fi;

# Install Dependencies
source "${BASH_SOURCE%/*}/scripts/dependencies.sh"
source "${BASH_SOURCE%/*}/scripts/cleanup.sh"

# Detect ROOT-Drive
source "${BASH_SOURCE%/*}/scripts/drive_detect.sh"

# Detect SSH-Server
source "${BASH_SOURCE%/*}/script/ssh_serverdetect.sh"
