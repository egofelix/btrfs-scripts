#!/bin/bash
if [[ $(getSystemName) = "ARCHLINUX" ]]; then
	source "${BASH_SOURCE%/*}/../systems/archlinux/dependencies.sh"
elif [[ $(getSystemName) = "DEBIAN" ]]; then
    source "${BASH_SOURCE%/*}/../systems/debian/dependencies.sh"
else
	logLine "Unknown system detected... Aborting"
	exit 1;
fi;
