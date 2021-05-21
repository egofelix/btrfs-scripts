#!/bin/bash
if [[ $(getSystemName) = "ARCHLINUX" ]]; then
  source "${BASH_SOURCE%/*}/../systems/archlinux/dependencies.sh"
elif [[ $(getSystemName) = "ALPINE" ]]; then
  source "${BASH_SOURCE%/*}/../systems/alpine/dependencies.sh"
elif [[ $(getSystemName) = "DEBIAN" ]]; then
  source "${BASH_SOURCE%/*}/../systems/debian/dependencies.sh"
else
  logError "Unknown system detected... Aborting"
  exit 1;
fi;
