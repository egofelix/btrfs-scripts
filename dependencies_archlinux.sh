#!/bin/bash

# Install wc
if ! which wc > /dev/null; then
	logLine "Installing dependency coreutils"
	pacman -Sy --noconfirm coreutils
fi;

# Install fdisk
if ! which fdisk > /dev/null; then
	logLine "Installing dependency fdisk"
	pacman -Sy --noconfirm util-linux
fi;

# Install grep
if ! which fdisk > /dev/null; then
	logLine "Installing dependency grep"
	pacman -Sy --noconfirm grep
fi;

# Install awk
if ! which awk > /dev/null; then
	logLine "Installing dependency gawk"
	pacman -Sy --noconfirm gawk
fi;

# Install parted
if ! which parted > /dev/null; then
	logLine "Installing dependency parted"
	pacman -Sy --noconfirm parted
fi;

# Install cryptsetup
if ! which cryptsetup > /dev/null; then
	logLine "Installing dependency cryptsetup"
	pacman -Sy --noconfirm cryptsetup
fi;

# Install btrfs-progs
if ! which btrfs > /dev/null; then
	logLine "Installing dependency cryptsetup"
	pacman -Sy --noconfirm btrfs-progs
fi;

# Install debootstrap
if ! which debootstrap > /dev/null; then
	logLine "Installing dependency debootstrap"
	pacman -Sy --noconfirm debootstrap
fi;

# Install genfstab
if ! which genfstab > /dev/null; then
	logLine "Installing dependency arch-install-scripts"
	pacman -Sy --noconfirm arch-install-scripts
fi;

# Install xargs
if ! which xargs > /dev/null; then
	logLine "Installing dependency findutils"
	pacman -Sy --noconfirm findutils
fi;

# Install sed
if ! which sed > /dev/null; then
	logLine "Installing dependency sed"
	pacman -Sy --noconfirm sed
fi;
