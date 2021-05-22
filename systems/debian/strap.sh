#!/bin/bash
if ! runCmd debootstrap stable /tmp/mnt/root; then
  logError "Failed to install Base-System"; exit 1;
fi;