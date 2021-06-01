#!/bin/bash
# Restore resolv.conf
rm -f /tmp/mnt/root/etc/resolv.conf
ln -s /run/systemd/resolve/stub-resolv.conf /tmp/mnt/root/etc/resolv.conf