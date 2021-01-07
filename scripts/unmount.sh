#!/bin/bash

# Unmount all disks
logDebug "Cleaning up"
for subvolName in ${SUBVOLUMES}
do
	umount -fR /tmp/mnt/root/${subvolName,,} &> /dev/null || true
done;
umount -fR /tmp/mnt/root &> /dev/null || true
umount -fR /tmp/mnt/disks/system &> /dev/null || true
umount -fR /tmp/mnt/backup &> /dev/null || true
rm -rf /tmp/mnt &> /dev/null || true

cryptsetup close cryptsystem &> /dev/null || true
cryptsetup close cryptbackup &> /dev/null || true
mdadm --stop /dev/md/raid &> /dev/null || true