#!/bin/bash
if ! runCmd debootstrap stable /tmp/mnt/root; then
  # Guess arch
  ARCH=$(uname -a)

  if [[ $ARCH = "x86_64" ]]; then
    ARCH="amd64"
  else
    logError "Failed to guess arch"; exit 1;
  fi;

  
  if ! runCmd debootstrap --arch $ARCH stable /tmp/mnt/root; then
    logError "Failed to install Base-System"; exit 1;
  fi;
fi;