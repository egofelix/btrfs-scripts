#!/bin/bash
if ! runCmd pacstrap /tmp/mnt/root base; then echo "Failed to install Base-System"; exit; fi;