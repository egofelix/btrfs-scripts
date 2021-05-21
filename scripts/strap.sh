#!/bin/bash
if [[ ${DISTRO^^} = "ARCHLINUX" ]]; then
  source "${BASH_SOURCE%/*}/../systems/archlinux/strap.sh"
elif [[ ${DISTRO^^} = "DEBIAN" ]]; then
  source "${BASH_SOURCE%/*}/../systems/debian/strap.sh"
elif [[ ${DISTRO^^} = "UBUNTU" ]]; then
  source "${BASH_SOURCE%/*}/../systems/ubuntu/strap.sh"
else
  logError "Unknown distro \"${DISTRO}\" detected... Aborting"
  exit 1;
fi;
