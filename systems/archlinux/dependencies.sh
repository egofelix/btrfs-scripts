#!/bin/bash

# Install wc
if ! which wc &> /dev/null; then
	logDebug "Installing dependency coreutils";
	pacman -Sy --noconfirm coreutils &> /dev/null;
fi;

# Install fdisk
if ! which fdisk &> /dev/null; then
	logDebug "Installing dependency fdisk"
	pacman -Sy --noconfirm util-linux &> /dev/null
fi;

# Install grep
if ! which fdisk &> /dev/null; then
	logDebug "Installing dependency grep";
	pacman -Sy --noconfirm grep &> /dev/null;
fi;

# Install awk
if ! which awk &> /dev/null; then
	logDebug "Installing dependency gawk";
	pacman -Sy --noconfirm gawk &> /dev/null;
fi;

# Install parted
if ! which parted &> /dev/null; then
	logDebug "Installing dependency parted";
	pacman -Sy --noconfirm parted &> /dev/null;
fi;

# Install cryptsetup
if ! which cryptsetup &> /dev/null; then
	logDebug "Installing dependency cryptsetup";
	pacman -Sy --noconfirm cryptsetup &> /dev/null;
fi;

# Install btrfs-progs
if ! which btrfs &> /dev/null; then
	logDebug "Installing dependency btrfs";
	pacman -Sy --noconfirm btrfs-progs &> /dev/null;
fi;

# Install genfstab
if ! which genfstab &> /dev/null; then
	logDebug "Installing dependency arch-install-scripts";
	pacman -Sy --noconfirm arch-install-scripts &> /dev/null;
fi;

# Install xargs
if ! which xargs &> /dev/null; then
	logDebug "Installing dependency findutils";
	pacman -Sy --noconfirm findutils &> /dev/null;
fi;

# Install sed
if ! which sed &> /dev/null; then
	logDebug "Installing dependency sed";
	pacman -Sy --noconfirm sed &> /dev/null;
fi;

# Install debootstrap
if [[ "${DISTRO^^}" == "DEBIAN" ]]; then
  if ! which debootstrap &> /dev/null; then
    logDebug "Installing dependency debootstrap";
    pacman -Sy --noconfirm debootstrap &> /dev/null;
  fi;
fi;