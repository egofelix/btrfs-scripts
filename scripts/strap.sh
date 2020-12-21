#!/bin/bash
if [[ $(getSystemName) = "ARCHLINUX" ]]; then
	source "${BASH_SOURCE%/*}/../systems/archlinux/strap.sh"
else
	logLine "Unknown system detected... Aborting"
	exit;
fi;
