#!/bin/bash
if ! runCmd debootstrap stable /tmp/mnt/root http://httpredir.debian.org/debian/; then
  logError "Failed to install Base-System"; exit 1;
fi;