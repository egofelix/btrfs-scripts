#!/bin/bash
apk update > /dev/null;

# Install wc
if ! which wc &> /dev/null; then
  logDebug "Installing dependency coreutils";
  if ! runCmd apk add coreutils; then logError "Failed to install dependency coreutils"; exit 1; fi;
fi;

# Install fdisk
if ! which fdisk &> /dev/null; then
  logDebug "Installing dependency fdisk"
  if ! runCmd apk add fdisk; then logError "Failed to install dependency fdisk"; exit 1; fi;
fi;

# Install grep
if ! which grep &> /dev/null; then
  logDebug "Installing dependency grep";
  if ! runCmd apk add grep; then logError "Failed to install dependency grep"; exit 1; fi;
fi;

# Install awk
if ! which awk &> /dev/null; then
  logDebug "Installing dependency gawk";
  if ! runCmd apk add gawk; then logError "Failed to install dependency gawk"; exit 1; fi;
fi;

# Install parted
if ! which parted &> /dev/null; then
  logDebug "Installing dependency parted";
  if ! runCmd apk add parted; then logError "Failed to install dependency parted"; exit 1; fi;
fi;

# Install cryptsetup
if ! which cryptsetup &> /dev/null; then
  logDebug "Installing dependency cryptsetup";
  if ! runCmd apk add cryptsetup; then logError "Failed to install dependency cryptsetup"; exit 1; fi;
fi;

# Install btrfs-progs
if ! which btrfs &> /dev/null; then
  logDebug "Installing dependency btrfs-progs";
  if ! runCmd apk add btrfs-progs; then logError "Failed to install dependency btrfs-progs"; exit 1; fi;
fi;

# Install genfstab
if ! which genfstab &> /dev/null; then
  logDebug "Installing dependency arch-install-scripts";
  if ! runCmd apk add arch-install-scripts; then logError "Failed to install dependency arch-install-scripts"; exit 1; fi;
fi;

# Install xargs
if ! which xargs &> /dev/null; then
  logDebug "Installing dependency findutils";
  if ! runCmd apk add findutils; then logError "Failed to install dependency findutils"; exit 1; fi;
fi;

# Install sed
if ! which sed &> /dev/null; then
  logDebug "Installing dependency sed";
  if ! runCmd apk add sed; then logError "Failed to install dependency sed"; exit 1; fi;
fi;

# Install dosfstools
if ! which mkfs.vfat &> /dev/null; then
  logDebug "Installing dependency dosfstools";
  if ! runCmd apk add dosfstools; then logError "Failed to install dependency dosfstools"; exit 1; fi;
fi;

# Install wget
if ! which wget &> /dev/null; then
  logDebug "Installing dependency wget";
  if ! runCmd apk add wget; then logError "Failed to install dependency wget"; exit 1; fi;
fi;

# Install curl
if ! which curl &> /dev/null; then
  logDebug "Installing dependency curl";
  if ! runCmd apk add curl; then logError "Failed to install dependency curl"; exit 1; fi;
fi;

# Install dig
if ! which dig &> /dev/null; then
  logDebug "Installing dependency bind-tools";
  if ! runCmd apk add bind-tools; then logError "Failed to install dependency bind-tools"; exit 1; fi;
fi;

# Install fatlabel
if ! which fatlabel &> /dev/null; then
  logDebug "Installing dependency dosfstools";
  if ! runCmd apk add dosfstools; then logError "Failed to install dependency dosfstools"; exit 1; fi;
fi;

# Install mkfs.ext2
if ! which mkfs.ext2 &> /dev/null; then
  logDebug "Installing dependency e2fsprogs";
  if ! runCmd apk add e2fsprogs; then logError "Failed to install dependency e2fsprogs"; exit 1; fi;
fi;

# Install chattr
if ! which chattr &> /dev/null; then
  logDebug "Installing dependency e2fsprogs-extra";
  if ! runCmd apk add e2fsprogs-extra; then logError "Failed to install dependency e2fsprogs-extra"; exit 1; fi;
fi;

# Install debootstrap
if [[ ${DISTRO^^} = "DEBIAN" ]]; then
  if ! which debootstrap &> /dev/null; then
    logDebug "Installing dependency debootstrap";
    if ! runCmd apk add debootstrap; then logError "Failed to install dependency debootstrap"; exit 1; fi;
  fi;

  if ! which perl &> /dev/null; then
    logDebug "Installing dependency perl";
    if ! runCmd apk add perl; then logError "Failed to install dependency perl"; exit 1; fi;
  fi;
fi;