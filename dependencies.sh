#!/bin/bash

if [[ $(getSystemName) = "ARCHLINUX" ]]; then
	source "${BASH_SOURCE%/*}/dependencies_archlinux.sh"
else
	logLine "Unknown system detected... Aborting"
	exit;
fi;
