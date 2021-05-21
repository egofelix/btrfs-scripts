#!/bin/bash
if ! runCmd pacstrap /tmp/mnt/root base; then
  if ! runCmd /tmp/arch-bootstrap.sh /tmp/mnt/root; then
    logError "Failed to install Base-System"; exit 1;
  fi;
fi;