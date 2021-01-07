#!/bin/bash
if ! runCmd debootstrap --variant=minbase focal /tmp/mnt/root http://de.archive.ubuntu.com/ubuntu; then echo "Failed to install Base-System"; exit; fi;