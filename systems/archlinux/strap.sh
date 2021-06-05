#!/bin/bash

if [[ ! -f "/etc/pacman.d/mirrorlist.bak" ]]; then
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
fi;

echo "Server = https://cached.egofelix.de/archlinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist

if ! runCmd pacstrap /tmp/mnt/root base; then
    if ! runCmd /tmp/arch-bootstrap.sh /tmp/mnt/root; then
        logError "Failed to install Base-System"; exit 1;
    fi;
fi;