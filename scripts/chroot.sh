#!/bin/bash
if [[ ${DISTRO^^} = "ARCHLINUX" ]]; then
	source "${BASH_SOURCE%/*}/../systems/archlinux/chroot.sh"
elif [[ ${DISTRO^^} = "DEBIAN" ]]; then
	source "${BASH_SOURCE%/*}/../systems/debian/chroot.sh"
elif [[ ${DISTRO^^} = "UBUNTU" ]]; then
	source "${BASH_SOURCE%/*}/../systems/ubuntu/chroot.sh"
else
	logLine "Unknown distro \"${DISTRO}\" detected... Aborting"
	exit 1;
fi;
