#!/bin/bash
if ! runCmd debootstrap stable /tmp/mnt/root http://debian.egofelix.de/; then
  # Guess arch
  if [[ $(getSystemType) = "AMD64" ]]; then
    ARCH="amd64"
  else
    logError "Failed to guess arch"; exit 1;
  fi;

  
  if ! runCmd debootstrap --arch $ARCH stable /tmp/mnt/root http://debian.egofelix.de/; then
    logError "Failed to install Base-System"; exit 1;
  fi;
fi;