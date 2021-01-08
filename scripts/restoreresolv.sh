#!/bin/bash
if [[ ${DISTRO^^} = "ARCHLINUX" ]]; then
	source "${BASH_SOURCE%/*}/../systems/archlinux/restoreresolv.sh"
elif [[ ${DISTRO^^} = "DEBIAN" ]]; then
	source "${BASH_SOURCE%/*}/../systems/debian/restoreresolv.sh"
elif [[ ${DISTRO^^} = "UBUNTU" ]]; then
	source "${BASH_SOURCE%/*}/../systems/ubuntu/restoreresolv.sh"
else
	logLine "Unknown distro \"${DISTRO}\" detected... Aborting"
	exit 1;
fi;
