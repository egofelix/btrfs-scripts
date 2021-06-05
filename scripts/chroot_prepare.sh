#!/bin/bash
if ! runCmd mkdir -p /tmp/mnt/root/tmp; then logLine "Error preparing chroot"; exit; fi;
if ! runCmd mount -t tmpfs tmpfs /tmp/mnt/root/tmp; then logLine "Error preparing chroot"; exit; fi;
if ! runCmd mount -t proc proc /tmp/mnt/root/proc; then logLine "Error preparing chroot"; exit; fi;
if ! runCmd mount -t sysfs sys /tmp/mnt/root/sys; then logLine "Error preparing chroot"; exit; fi;
if ! runCmd mount -t devtmpfs dev /tmp/mnt/root/dev; then logLine "Error preparing chroot"; exit; fi;
if ! runCmd mount -t devpts devpts /tmp/mnt/root/dev/pts; then logLine "Error preparing chroot"; exit; fi;

runCmd mount -t efivarfs efivarfs /tmp/mnt/root/sys/firmware/efi/efivars;

# Install current resolv.conf
if ! runCmd cp /etc/resolv.conf /tmp/mnt/root/etc/resolv.conf; then logLine "Error preparing chroot"; exit; fi;