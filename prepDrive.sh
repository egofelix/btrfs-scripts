#!/bin/bash
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
	if ! runCmd cryptsetup --batch-mode luksFormat --type luks2 --cipher aes-xts-plain64 --key-size 512 --hash sha512 --pbkdf argon2i --sector-size 512 --use-urandom -d /tmp/crypto.key ${PART_SYSTEM}; then echo "Failed to cryptformat SYSTEM-Partiton"; exit; fi;
	if ! runCmd cryptsetup --batch-mode open ${PART_SYSTEM} cryptsystem -d /tmp/crypto.key; then echo "Failed to open CRYPTSYSTEM-Partition"; exit; fi;
	
	# Backup luks header
	rm -f /tmp/crypto.header &> /dev/null
	if ! runCmd cryptsetup luksHeaderBackup ${PART_SYSTEM} --header-backup-file /tmp/crypto.header; then logLine "Failed to Backup LUKS-Header"; exit; fi;
	
	# Add Password
	echo ${CRYPTEDPASSWORD} | cryptsetup --batch-mode luksAddKey /dev/sda3 -d /tmp/crypto.key; 
	if [ $? -ne 0 ]; then logLine "Failed to add password to SYSTEM-Partition"; exit; fi;
	
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
logLine "Creating BTRFS-Subvolumes on SYSTEM-Partition...";
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

mkdir -p /tmp/mnt/root/.snapshots
if ! runCmd mount -o subvol=/snapshots ${PART_SYSTEM} /tmp/mnt/root/.snapshots; then echo "Failed to Mount Snapshot-Volume at /tmp/mnt/root/.snapshots"; exit; fi;

if isEfiSystem; then
	mkdir -p /tmp/mnt/root/boot/efi
	if ! runCmd mount ${PART_EFI} /tmp/mnt/root/boot/efi; then echo "Failed to mount BOOT-Partition"; exit; fi;
fi;
for subvolName in ${SUBVOLUMES}
do
	mkdir -p /tmp/mnt/root/${subvolName,,}
	if ! runCmd mount -o subvol=/${subvolName,,}-data ${PART_SYSTEM} /tmp/mnt/root/${subvolName,,}; then echo "Failed to Mount Subvolume ${subvolName^^}-DATA at /tmp/mnt/root/${subvolName,,}"; exit; fi;
done;