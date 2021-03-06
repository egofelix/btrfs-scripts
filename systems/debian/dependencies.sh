#!/bin/bash

# Install wc
if ! which wc &> /dev/null; then
	logDebug "Installing dependency coreutils";
	DEBIAN_FRONTEND=noninteractive apt-get -yq install coreutils &> /dev/null;
fi;

# Install fdisk
if ! which fdisk &> /dev/null; then
	logDebug "Installing dependency fdisk"
	DEBIAN_FRONTEND=noninteractive apt-get -yq install fdisk &> /dev/null;
fi;

# Install grep
if ! which grep &> /dev/null; then
	logDebug "Installing dependency grep";
	DEBIAN_FRONTEND=noninteractive apt-get -yq install grep &> /dev/null;
fi;

# Install awk
if ! which awk &> /dev/null; then
	logDebug "Installing dependency gawk";
	DEBIAN_FRONTEND=noninteractive apt-get -yq install gawk &> /dev/null;
fi;

# Install parted
if ! which parted &> /dev/null; then
	logDebug "Installing dependency parted";
	DEBIAN_FRONTEND=noninteractive apt-get -yq install parted &> /dev/null;
fi;

# Install cryptsetup
if ! which cryptsetup &> /dev/null; then
	logDebug "Installing dependency cryptsetup";
	DEBIAN_FRONTEND=noninteractive apt-get -yq install cryptsetup &> /dev/null;
fi;

# Install btrfs-progs
if ! which btrfs &> /dev/null; then
	logDebug "Installing dependency btrfs-progs";
	DEBIAN_FRONTEND=noninteractive apt-get -yq install btrfs-progs &> /dev/null;
fi;

# Install genfstab
if ! which genfstab &> /dev/null; then
	logDebug "Installing dependency arch-install-scripts";
	DEBIAN_FRONTEND=noninteractive apt-get -yq install arch-install-scripts &> /dev/null;
fi;

# Install xargs
if ! which xargs &> /dev/null; then
	logDebug "Installing dependency findutils";
	DEBIAN_FRONTEND=noninteractive apt-get -yq install findutils &> /dev/null;
fi;

# Install sed
if ! which sed &> /dev/null; then
	logDebug "Installing dependency sed";
	DEBIAN_FRONTEND=noninteractive apt-get -yq install sed &> /dev/null;
fi;

# Install dosfstools
if ! which mkfs.vfat &> /dev/null; then
	logDebug "Installing dependency dosfstools";
	DEBIAN_FRONTEND=noninteractive apt-get -yq install dosfstools &> /dev/null;
fi;

# Install wget
if ! which wget &> /dev/null; then
	logDebug "Installing dependency wget";
	DEBIAN_FRONTEND=noninteractive apt-get -yq install wget &> /dev/null;
fi;

# Install curl
if ! which curl &> /dev/null; then
	logDebug "Installing dependency curl";
	DEBIAN_FRONTEND=noninteractive apt-get -yq install curl &> /dev/null;
fi;

# Install dig
if ! which dig &> /dev/null; then
	logDebug "Installing dependency dnsutils ";
	DEBIAN_FRONTEND=noninteractive apt-get -yq install dnsutils &> /dev/null;
fi;