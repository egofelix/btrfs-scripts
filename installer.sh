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
if [[ -z ${DRIVE_ROOT:-} ]]; then
	# Scan HDDs
	HDDS=`LANG=C fdisk -l | grep 'Disk \/dev\/' | grep -v 'loop' | awk '{print $2}' | awk -F':' '{print $1}'`
	HDD_COUNT=$(countLines "${HDDS}")

	if [[ ${HDD_COUNT} -eq 0 ]];
	then
		logLine "No drives present. Aborting"
		exit
	fi;

	DRIVE_ROOT=""
	# Assign HDDs to Partitons/Volumes
	for item in $HDDS
	do
		if [[ -z "${DRIVE_ROOT}" ]];
		then
			DRIVE_ROOT="$item"
		fi;
	done;
	
	# Abort if no drive was found
	if [[ -z "${DRIVE_ROOT}" ]]; then
		echo "No Drive found";
		exit;
	fi;
fi;

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

# Format drives
logLine "Partitioning ROOT-Drive..."

if isEfiSystem; then
	logLine "Using EFI partition scheme...";
	sfdisk -q ${DRIVE_ROOT} &> /dev/null <<- EOM
label: gpt
unit: sectors

start=        2048, size=      204800, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="efi"
start=      206848, size=      512000, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="boot"
start=      718848, size=      204800, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="system"
EOM

	# Check Result
	if [ $? -ne 0 ]; then
		logLine "Failed to partition the root drive! Aborting"
		exit
	fi;
	
	# Remember partitions
	PART_EFI="${DRIVE_ROOT}1";
	PART_BOOT="${DRIVE_ROOT}2";
	PART_SYSTEM="${DRIVE_ROOT}3";
	PART_SYSTEM_NUM="3";
else
	logLine "Using BIOS partition scheme..."
	sfdisk -q ${DRIVE_ROOT} &> /dev/null <<- EOM
label: gpt
unit: sectors

start=2048, size=512000, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="boot"
start=514048, size=204800, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="root"
EOM

	# Check Result
	if [ $? -ne 0 ]; then
		logLine "Failed to partition ROOT-Drive"
		exit
	fi;

	# Remember partitions
	PART_EFI=""
	PART_BOOT="${DRIVE_ROOT}1"
	PART_SYSTEM="${DRIVE_ROOT}2"
	PART_SYSTEM_NUM="2"
fi;

if ! runCmd parted ${DRIVE_ROOT} resizepart ${PART_SYSTEM_NUM} 100%; then logLine "Failed to expand ROOT-Partition"; exit; fi;

# Sync drives
sleep 1
sync
sleep 1

# Format EFI-Partition
if [[ ! -z "${PART_EFI}" ]]; then
    logLine "Formatting EFI-Partition...";
    if ! runCmd mkfs.vfat -F32 ${PART_EFI}; then logLine "Failed to Format EFI-Partition."; exit; fi;
    if ! runCmd fatlabel ${PART_EFI} EFI; then logLine "Failed to label EFI-Partition."; exit; fi;
fi;

# Format BOOT-Partition
logLine "Formatting BOOT-Partition...";
if ! runCmd mkfs.ext2 -F -L boot ${PART_BOOT}; then echo "Failed to format BOOT-Partition"; exit; fi;

# Encrypt SYSTEM-Partition
if isTrue "${CRYPTED}"; then
	if [[ ! -f /tmp/crypto.key ]]; then
		logLine "Generating Crypto-KEY...";
		if ! runCmd dd if=/dev/urandom of=/tmp/crypto.key bs=1024 count=1; then echo "Failed to generate Crypto-KEY"; exit; fi;
	fi;
	
	logLine "Encrypting SYSTEM-Partition";
	if ! runCmd cryptsetup --batch-mode luksFormat --type luks1 -d /tmp/crypto.key ${PART_SYSTEM}; then echo "Failed to cryptformat SYSTEM-Partiton"; exit; fi;
	if ! runCmd cryptsetup --batch-mode open ${PART_SYSTEM} cryptsystem -d /tmp/crypto.key; then echo "Failed to open CRYPTSYSTEM-Partition"; exit; fi;
	
	# Remap partition to crypted one
	PART_SYSTEM="/dev/mapper/cryptsystem"
fi;

# Format Partition
logLine "Formatting SYSTEM-Partition";
if ! runCmd mkfs.btrfs -f -L system ${PART_SYSTEM}; then echo "Failed to format SYSTEM-Partition"; exit; fi;
		
# Mount Partition
logLine "Mounting SYSTEM-Partition at /tmp/mnt/disks/system"
mkdir -p /tmp/mnt/disks/system
if ! runCmd mount ${PART_SYSTEM} /tmp/mnt/disks/system; then echo "Failed to mount SYSTEM-Partition"; exit; fi;

# Create Subvolumes
logLine "Creating BTRFS-Subvolumes on SYSTEM-Partition";
if ! runCmd btrfs subvolume create /tmp/mnt/disks/system/snapshots; then echo "Failed to create btrfs SNAPSHOTS-Volume on ${partName^^}-Partition"; exit; fi;
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
if isEfiSystem; then
	mkdir -p /tmp/mnt/root/boot/efi
	if ! runCmd mount ${PART_EFI} /tmp/mnt/root/boot/efi; then echo "Failed to mount BOOT-Partition"; exit; fi;
fi;
for subvolName in ${SUBVOLUMES}
do
	mkdir -p /tmp/mnt/root/${subvolName,,}
	if ! runCmd mount -o subvol=/${subvolName,,}-data ${PART_SYSTEM} /tmp/mnt/root/${subvolName,,}; then echo "Failed to Mount Subvolume ${subvolName^^}-DATA at /tmp/mnt/root/${subvolName,,}"; exit; fi;
done;

# Install base system
logLine "Installing Base-System"
#debootstrap stable /tmp/mnt/root http://ftp.de.debian.org/debian/;
if ! runCmd pacstrap /tmp/mnt/root base linux linux-firmware; then echo "Failed to install Base-System"; exit; fi;

# Generate fstab
genfstab -pL /tmp/mnt/root >> /tmp/mnt/root/etc/fstab;
if [ $? -ne 0 ]; then
	logLine "Failed to generate fstab";
	exit
fi;
if ! runCmd sed -i 's/,subvolid=[0-9]*//g' /tmp/mnt/root/etc/fstab; then echo "Failed to modify fstab"; exit; fi;


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
fi;


# Run in chroot
#chroot /tmp/mnt/root /bin/bash
#pacman -Sy --noconfirm grub efibootmgr
#grub-install


# Cleanup
#source "${BASH_SOURCE%/*}/cleanup.sh"
