#!/bin/bash

if isTrue ${RAID:-}; then
  mdadm --zero-superblock ${DRIVE_ROOT_A}3
  mdadm --zero-superblock ${DRIVE_ROOT_A}2
  mdadm --zero-superblock ${DRIVE_ROOT_A}1
  mdadm --zero-superblock ${DRIVE_ROOT_A}
  mdadm --zero-superblock ${DRIVE_ROOT_B}3
  mdadm --zero-superblock ${DRIVE_ROOT_B}2
  mdadm --zero-superblock ${DRIVE_ROOT_B}1
  mdadm --zero-superblock ${DRIVE_ROOT_B}
  #DRIVE_ROOT=/dev/md/raid
  sync
  echo "Partitioning raid disks...";
  for DRIVE_ROOT in "${DRIVE_ROOT_A}" "${DRIVE_ROOT_B}"
  do
	if [[ "${BIOSTYPE}" == "EFI" ]]; then
		logLine "Using EFI partition scheme...";
		echo sfdisk -q ${DRIVE_ROOT}
		sfdisk -q ${DRIVE_ROOT} &> /dev/null <<- EOM
	label: gpt
	unit: sectors

	start=        2048, size=      204800, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="efi"
	start=      206848, size=      512000, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="boot"
	start=      718848, size=      204800, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="system"
	EOM

		# Check Result
		if [ $? -ne 0 ]; then
			logLine "Failed to partition the drive! Aborting"
			exit
		fi;
		
		export PART_SYSTEM_NUM="3";
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
		
		export PART_SYSTEM_NUM="2";
	fi;
	
	if ! runCmd parted -s ${DRIVE_ROOT} resizepart ${PART_SYSTEM_NUM} 100%; then logLine "Failed to expand ROOT-Partition"; exit; fi;
  done;
  
  sync
  echo "Creating raids...";
  if [[ "${BIOSTYPE}" == "EFI" ]]; then
    RAIDRESULT=$(echo yes | mdadm --create /dev/md/raid_efi --metadata=0.90 --level=1 --raid-devices=2 ${DRIVE_ROOT_A}1 ${DRIVE_ROOT_B}1)
    if [ $? -ne 0 ]; then
	  logLine "Failed to prepare raid_efi. aborting."
      exit
    fi;
    RAIDRESULT=$(echo yes | mdadm --create /dev/md/raid_boot --metadata=0.90 --level=1 --raid-devices=2 ${DRIVE_ROOT_A}2 ${DRIVE_ROOT_B}2)
    if [ $? -ne 0 ]; then
	  logLine "Failed to prepare raid_boot. aborting."
	  exit
    fi;
	RAIDRESULT=$(echo yes | mdadm --create /dev/md/raid_root --level=1 --raid-devices=2 ${DRIVE_ROOT_A}3 ${DRIVE_ROOT_B}3)
    if [ $? -ne 0 ]; then
	  logLine "Failed to prepare raid_root. aborting."
	  exit
    fi;
	
    # Remember partitions
	export PART_EFI="/dev/md/raid_efi";
	export PART_BOOT="/dev/md/raid_boot";
	export PART_SYSTEM="/dev/md/raid_root";
  else
    RAIDRESULT=$(echo yes | mdadm --create /dev/md/raid_boot --metadata=0.90 --level=1 --raid-devices=2 ${DRIVE_ROOT_A}1 ${DRIVE_ROOT_B}1)
    if [ $? -ne 0 ]; then
	  logLine "Failed to prepare raid_boot. aborting."
	  exit
    fi;
	RAIDRESULT=$(echo yes | mdadm --create /dev/md/raid_root --level=1 --raid-devices=2 ${DRIVE_ROOT_A}2 ${DRIVE_ROOT_B}2)
    if [ $? -ne 0 ]; then
	  logLine "Failed to prepare raid_root. aborting."
	  exit
    fi;
	
	export PART_EFI="";
	export PART_BOOT="/dev/md/raid_boot";
	export PART_SYSTEM="/dev/md/raid_root";
  fi;
else
	# Format drives
	logLine "Partitioning ${DRIVE_ROOT}..."

	if [[ "${BIOSTYPE}" == "EFI" ]]; then
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
			logLine "Failed to partition the drive! Aborting"
			exit
		fi;
		
		# Remember partitions
		export PART_EFI="${DRIVE_ROOT}1";
		export PART_BOOT="${DRIVE_ROOT}2";
		export PART_SYSTEM="${DRIVE_ROOT}3";
		export PART_SYSTEM_NUM="3";
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
		export PART_EFI=""
		export PART_BOOT="${DRIVE_ROOT}1"
		export PART_SYSTEM="${DRIVE_ROOT}2"
		export PART_SYSTEM_NUM="2"
	fi;

	if ! runCmd parted -s ${DRIVE_ROOT} resizepart ${PART_SYSTEM_NUM} 100%; then logLine "Failed to expand ROOT-Partition"; exit; fi;
fi;

# Sync drives
sleep 1
sync
sleep 1

# Format EFI-Partition
if [[ ! -z "${PART_EFI}" ]]; then
    logLine "Formatting EFI-Partition (${PART_EFI})...";
    if ! runCmd mkfs.vfat -F32 ${PART_EFI}; then logLine "Failed to Format EFI-Partition."; exit; fi;
    if ! runCmd fatlabel ${PART_EFI} EFI; then logLine "Failed to label EFI-Partition."; exit; fi;
fi;

# Format BOOT-Partition
logLine "Formatting BOOT-Partition (${PART_BOOT})...";
if ! runCmd mkfs.ext2 -F -L boot ${PART_BOOT}; then echo "Failed to format BOOT-Partition"; exit; fi;

# Encrypt SYSTEM-Partition
if isTrue "${CRYPTED}"; then
	if [[ ! -f /tmp/crypto.key ]]; then
		logLine "Generating Crypto-KEY...";
		if ! runCmd dd if=/dev/urandom of=/tmp/crypto.key bs=1024 count=1; then echo "Failed to generate Crypto-KEY"; exit; fi;
	fi;
	
	logLine "Encrypting SYSTEM-Partition (${PART_SYSTEM})...";
	if ! runCmd cryptsetup --batch-mode luksFormat --type luks2 --cipher aes-xts-plain64 --key-size 256 --hash sha256 --pbkdf argon2i -d /tmp/crypto.key ${PART_SYSTEM}; then echo "Failed to cryptformat SYSTEM-Partiton"; exit; fi;
	if ! runCmd cryptsetup --batch-mode open ${PART_SYSTEM} cryptsystem -d /tmp/crypto.key; then echo "Failed to open CRYPTSYSTEM-Partition"; exit; fi;
	
	# Backup luks header
	rm -f /tmp/crypto.header &> /dev/null
	if ! runCmd cryptsetup luksHeaderBackup ${PART_SYSTEM} --header-backup-file /tmp/crypto.header; then logLine "Failed to Backup LUKS-Header"; exit; fi;
	
	# Add Password
	echo ${CRYPTEDPASSWORD} | cryptsetup --batch-mode luksAddKey ${PART_SYSTEM} -d /tmp/crypto.key; 
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