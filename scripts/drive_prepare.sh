#!/bin/bash

# Format drives
logLine "Partitioning ${DRIVE_ROOT}..."
sfdisk -q ${DRIVE_ROOT} &> /dev/null <<- EOM
label: gpt
unit: sectors

start=2048, size=20480, type=21686148-6449-6E6F-744E-656564454649, bootable
start=22528, size=204800, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="efi"
start=227328, size=512000, type=BC13C2FF-59E6-4262-A352-B275FD6F7172, name="boot"
start=739328, size=512000, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="system"
EOM

# Check Result
if [ $? -ne 0 ]; then
	logLine "Failed to partition ROOT-Drive"
	exit
fi;

# Remember partitions
export PART_EFI="${DRIVE_ROOT}2"
export PART_BOOT="${DRIVE_ROOT}3"
export PART_SYSTEM="${DRIVE_ROOT}4"
export PART_SYSTEM_NUM="4"

if ! runCmd parted -s ${DRIVE_ROOT} resizepart ${PART_SYSTEM_NUM} 100%; then logError "Failed to expand ROOT-Partition"; exit 1; fi;

# Sync drives
sleep 1
sync
sleep 1

# Format EFI-Partition
if [[ ! -z "${PART_EFI}" ]]; then
    logLine "Formatting EFI-Partition (${PART_EFI})...";
    if ! runCmd mkfs.vfat -F32 ${PART_EFI}; then logError "Failed to Format EFI-Partition."; exit 1; fi;
    if ! runCmd fatlabel ${PART_EFI} EFI; then logError "Failed to label EFI-Partition."; exit 1; fi;
fi;

# Format BOOT-Partition
logLine "Formatting BOOT-Partition (${PART_BOOT})...";
if ! runCmd mkfs.ext2 -F -L boot ${PART_BOOT}; then logError "Failed to format BOOT-Partition"; exit 1; fi;

# Encrypt SYSTEM-Partition
if isTrue "${CRYPTED}"; then
	if [[ ! -f /tmp/crypto.key ]]; then
		logLine "Generating Crypto-KEY...";
		if ! runCmd dd if=/dev/urandom of=/tmp/crypto.key bs=1024 count=1; then logError "Failed to generate Crypto-KEY"; exit 1; fi;
	fi;
	
	logLine "Encrypting SYSTEM-Partition (${PART_SYSTEM})...";
	if ! runCmd cryptsetup --batch-mode luksFormat --type luks2 --cipher aes-xts-plain64 --key-size 256 --hash sha256 --pbkdf argon2i -d /tmp/crypto.key ${PART_SYSTEM}; then logError "Failed to cryptformat SYSTEM-Partiton"; exit 1; fi;
	if ! runCmd cryptsetup --batch-mode open ${PART_SYSTEM} cryptsystem -d /tmp/crypto.key; then logError "Failed to open CRYPTSYSTEM-Partition"; exit 1; fi;
	
	# Backup luks header
	rm -f /tmp/crypto.header &> /dev/null
	if ! runCmd cryptsetup luksHeaderBackup ${PART_SYSTEM} --header-backup-file /tmp/crypto.header; then logError "Failed to Backup LUKS-Header"; exit 1; fi;
	
	# Add Password
	echo ${CRYPTEDPASSWORD} | cryptsetup --batch-mode luksAddKey ${PART_SYSTEM} -d /tmp/crypto.key; 
	if [ $? -ne 0 ]; then logError "Failed to add password to SYSTEM-Partition"; exit 1; fi;
	
	# Remap partition to crypted one
	PART_SYSTEM="/dev/mapper/cryptsystem"
fi;

# Format Partition
logLine "Formatting SYSTEM-Partition";
if ! runCmd mkfs.btrfs -f -L system ${PART_SYSTEM}; then logError "Failed to format SYSTEM-Partition"; exit 1; fi;

# Mount Partition
logLine "Mounting SYSTEM-Partition at /tmp/mnt/disks/system"
mkdir -p /tmp/mnt/disks/system
if ! runCmd mount ${PART_SYSTEM} /tmp/mnt/disks/system; then logError "Failed to mount SYSTEM-Partition"; exit 1; fi;