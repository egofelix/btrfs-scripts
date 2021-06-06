#!/bin/bash

# Todo, detect system here
SYSTEMID=$(cat /tmp/mnt/root/etc/os-release | grep "^ID=");

if [[ "${SYSTEMID^^}" = *"DEBIAN"* ]];
then
    source "${BASH_SOURCE%/*}/../systems/debian/bootmanager.sh";
elif [[ "${SYSTEMID^^}" = *"ARCH"* ]];
then
    source "${BASH_SOURCE%/*}/../systems/archlinux/bootmanager.sh";
else
    logError "Unable to detect system, skipping bootmanager!";
fi;
