#!/bin/bash
if ! runCmd debootstrap stable /tmp/mnt/root http://cached.egofelix.de/debian/; then
    # Guess arch
    if [[ system-arch = "AMD64" ]]; then
        ARCH="amd64"
    else
        logError "Failed to guess arch"; exit 1;
    fi;
    
    
    if ! runCmd debootstrap --arch $ARCH stable /tmp/mnt/root http://cached.egofelix.de/debian/; then
        logError "Failed to install Base-System"; exit 1;
    fi;
fi;