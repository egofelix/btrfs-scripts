#!/bin/bash
if system-name "ARCHLINUX";
then
    source "${BASH_SOURCE%/*}/../systems/archlinux/dependencies.sh"
elif system-name "ALPINE";
then
    source "${BASH_SOURCE%/*}/../systems/alpine/dependencies.sh"
elif system-name "DEBIAN";
then
    source "${BASH_SOURCE%/*}/../systems/debian/dependencies.sh"
else
    logError "Unknown system detected... Aborting"
    exit 1;
fi;
