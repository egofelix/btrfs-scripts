#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/functions.sh"

# Load Variables
source "${BASH_SOURCE%/*}/defaults.sh"

## Script must be started as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root";
  exit;
fi;

# Install Dependencies
source "${BASH_SOURCE%/*}/dependencies.sh"
source "${BASH_SOURCE%/*}/cleanup.sh"

# Detect ROOT-Drive
source "${BASH_SOURCE%/*}/detectRoot.sh"

# Print INFO
echo
echo "System will be installed to: ${DRIVE_ROOT}"
if isTrue "${CRYPTED}"; then
	echo "The System will be encrypted with cryptsetup";
fi;
echo

# Get user confirmation
read -p "Continue? (Any data on the drive will be ereased) [yN]: " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Script canceled by user";
    exit;   
fi

# Prepare drive
source "${BASH_SOURCE%/*}/prepDrive.sh"

# Create Subvolumes
logLine "Creating BTRFS-Subvolumes on SYSTEM-Partition...";
if ! runCmd btrfs subvolume create /tmp/mnt/disks/system/@snapshots; then echo "Failed to create btrfs SNAPSHOTS-Volume"; exit; fi;
if ! runCmd btrfs subvolume create /tmp/mnt/disks/system/@swap; then echo "Failed to create btrfs SWAP-Volume"; exit; fi;
if ! runCmd btrfs subvolume create /tmp/mnt/disks/system/root-data; then echo "Failed to create btrfs ROOT-DATA-Volume"; exit; fi;
for subvolName in ${SUBVOLUMES}
do
	if ! runCmd btrfs subvolume create /tmp/mnt/disks/system/${subvolName,,}-data; then echo "Failed to create btrfs ${subvolName^^}-DATA-Volume"; exit; fi;
done;
	
# Mount Subvolumes
logLine "Mounting..."
mkdir -p /tmp/mnt/root
if ! runCmd mount -o subvol=/root-data ${PART_SYSTEM} /tmp/mnt/root; then echo "Failed to Mount Subvolume ROOT-DATA at /tmp/mnt/root"; exit; fi;
mkdir -p /tmp/mnt/root/boot
if ! runCmd mount ${PART_BOOT} /tmp/mnt/root/boot; then echo "Failed to mount BOOT-Partition"; exit; fi;

# Create Snapshot-Volume
mkdir -p /tmp/mnt/root/.snapshots
if ! runCmd mount -o subvol=@snapshots ${PART_SYSTEM} /tmp/mnt/root/.snapshots; then echo "Failed to Mount Snapshot-Volume at /tmp/mnt/root/.snapshots"; exit; fi;

# Create Swap-Volume and Swap-File
mkdir -p /tmp/mnt/root/.swap
if ! runCmd mount -o subvol=@swap ${PART_SYSTEM} /tmp/mnt/root/.swap; then echo "Failed to Mount Swap-Volume at /tmp/mnt/root/.swap"; exit; fi;
if ! runCmd truncate -s 0 /tmp/mnt/root/.swap/swapfile; then echo "Failed to truncate Swap-File at /tmp/mnt/root/.swap/swapfile"; exit; fi;
if ! runCmd chattr +C /tmp/mnt/root/.swap/swapfile; then echo "Failed to chattr Swap-File at /tmp/mnt/root/.swap/swapfile"; exit; fi;
if ! runCmd chmod 600 /tmp/mnt/root/.swap/swapfile; then echo "Failed to chmod Swap-File at /tmp/mnt/root/.swap/swapfile"; exit; fi;
if ! runCmd btrfs property set /tmp/mnt/root/.swap/swapfile compression none; then echo "Failed to disable compression for Swap-File at /tmp/mnt/root/.swap/swapfile"; exit; fi;
if ! runCmd fallocate /tmp/mnt/root/.swap/swapfile -l2g; then echo "Failed to fallocate 2G Swap-File at /tmp/mnt/root/.swap/swapfile"; exit; fi;
if ! runCmd mkswap /tmp/mnt/root/.swap/swapfile; then echo "Failed to mkswap for Swap-File at /tmp/mnt/root/.swap/swapfile"; exit; fi;

# Mount EFI
if [[ "${BIOSTYPE}" == "EFI" ]]; then
	mkdir -p /tmp/mnt/root/boot/efi
	if isEfiSystem; then
		if ! runCmd mount ${PART_EFI} /tmp/mnt/root/boot/efi; then echo "Failed to mount BOOT-Partition"; exit; fi;
	fi;
fi;

# Mount Subvolumes
for subvolName in ${SUBVOLUMES}
do
	mkdir -p /tmp/mnt/root/${subvolName,,}
	if ! runCmd mount -o subvol=/${subvolName,,}-data ${PART_SYSTEM} /tmp/mnt/root/${subvolName,,}; then echo "Failed to Mount Subvolume ${subvolName^^}-DATA at /tmp/mnt/root/${subvolName,,}"; exit; fi;
done;

# Install base system
logLine "Installing Base-System (${DISTRO^^})..."
if [[ "${DISTRO^^}" == "DEBIAN" ]]; then
	if ! runCmd debootstrap stable /tmp/mnt/root http://ftp.de.debian.org/debian/; then echo "Failed to install Base-System"; exit; fi;
elif [[ "${DISTRO^^}" == "ARCHLINUX" ]]; then
	if ! runCmd pacstrap /tmp/mnt/root base; then echo "Failed to install Base-System"; exit; fi;
fi;

# Generate fstab
genfstab -pL /tmp/mnt/root >> /tmp/mnt/root/etc/fstab;
if [ $? -ne 0 ]; then
	logLine "Failed to generate fstab";
	exit
fi;
if ! runCmd sed -i 's/,subvolid=[0-9]*//g' /tmp/mnt/root/etc/fstab; then echo "Failed to modify fstab"; exit; fi;
if ! runCmd sed -i 's/,subvol=\/[^,]*//g' /tmp/mnt/root/etc/fstab; then echo "Failed to modify fstab"; exit; fi;

# Prepare CHRoot
if ! runCmd mkdir -p /tmp/mnt/root/tmp; then logLine "Error preparing chroot"; exit; fi;
if ! runCmd mount -t tmpfs tmpfs /tmp/mnt/root/tmp; then logLine "Error preparing chroot"; exit; fi;
if ! runCmd mount -t proc proc /tmp/mnt/root/proc; then logLine "Error preparing chroot"; exit; fi;
if ! runCmd mount -t sysfs sys /tmp/mnt/root/sys; then logLine "Error preparing chroot"; exit; fi;
if ! runCmd mount -t devtmpfs dev /tmp/mnt/root/dev; then logLine "Error preparing chroot"; exit; fi;
if ! runCmd mount -t devpts devpts /tmp/mnt/root/dev/pts; then logLine "Error preparing chroot"; exit; fi;
if isEfiSystem; then
	if ! runCmd mount -t efivarfs efivarfs /tmp/mnt/root/sys/firmware/efi/efivars; then logLine "Error preparing chroot"; exit; fi;
fi;

# Install current resolv.conf
if ! runCmd cp /etc/resolv.conf /tmp/mnt/root/etc/resolv.conf; then logLine "Error preparing chroot"; exit; fi;

if isTrue "${CRYPTED}"; then
	if ! runCmd cp /tmp/crypto.key /tmp/mnt/root/etc/; then logLine "Failed to copy crypto.key"; exit; fi;
	if ! runCmd cp /tmp/crypto.header /tmp/mnt/root/etc/; then logLine "Failed to copy crypto.header"; exit; fi;
fi;

# Run installer
logLine "Setting up system...";
if [[ "${DISTRO^^}" == "DEBIAN" ]]; then
	source "${BASH_SOURCE%/*}/chroot_debian.sh"
elif [[ "${DISTRO^^}" == "ARCHLINUX" ]]; then
	source "${BASH_SOURCE%/*}/chroot_archlinux.sh"
fi;

# Cleanup
#source "${BASH_SOURCE%/*}/cleanup.sh";

# Finish
logLine "Your system is ready! Type reboot to boot it.";
