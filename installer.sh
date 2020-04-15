#!/bin/bash

# Parse arguments
function parseArguments {
	CRYPTED="TRUE"
	TARGET_SYSTEM="DEBIAN"
	
	DEV_AUTO="TRUE"
	
	DEV_ROOT="/dev/sda"
	DEV_ROOT_FS="btrfs"
	DEV_ROOT_PART="2"

	DEV_HOME=""
	DEV_HOME_FS="btrfs"
	DEV_HOME_PART="1"

	DEV_OPT=""
	DEV_OPT_FS="btrfs"
	DEV_OPT_PART="1"

	DEV_SRV=""
	DEV_SRV_FS="btrfs"
	DEV_SRV_PART="1"

	DEV_USR=""
	DEV_USR_FS="btrfs"
	DEV_USR_PART="1"

	DEV_VAR=""
	DEV_VAR_FS="btrfs"
	DEV_VAR_PART="1"

	FILESYS="btrfs"
	VERBOSE=""
	TARGET_HOSTNAME=""

	AUTOREBOOT="FALSE"

	IS_EFI="TRUE"
	ROOT_SIZE=""
	STOP_AT_INSTALL_BASE="FALSE"
	CIPHER=""

	URL_BACKUP=""
	URL_RESTORE=""

	while [ "$#" -gt 0 ]; do
	  case "$1" in
		  --verbose) export VERBOSE="true"; shift 1;;
		  #--system) export TARGET_SYSTEM="$2"; shift 2;;
		  
		  #--fs) export DEV_ROOT_FS="$2"; export export DEV_HOME_FS="$2"; export DEV_OPT_FS="$2"; export DEV_SRV_FS="$2"; export DEV_USR_FS="$2"; export DEV_VAR_FS="$2"; shift 2;;

		  --root) export DEV_ROOT="$2"; DEV_AUTO="FALSE"; shift 2;;
		  #--root-fs) export DEV_ROOT_FS="$2"; shift 2;;

		  --home) export DEV_HOME="$2"; DEV_AUTO="FALSE"; shift 2;;
		  #--home-fs) export DEV_HOME_FS="$2"; shift 2;;

		  --opt) export DEV_OPT="$2"; DEV_AUTO="FALSE"; shift 2;;
		  #--opt-fs) export DEV_OPT_FS="$2"; shift 2;;

		  --srv) export DEV_SRV="$2"; DEV_AUTO="FALSE"; shift 2;;
		  #--srv-fs) export DEV_SRV_FS="$2"; shift 2;;

		  --usr) export DEV_USR="$2"; DEV_AUTO="FALSE"; shift 2;;
		  #--usr-fs) export DEV_USR_FS="$2"; shift 2;;

		  --var) export DEV_VAR="$2"; DEV_AUTO="FALSE"; shift 2;;
		  #--var-fs) export DEV_VAR_FS="$2"; shift 2;;
		  
		  --backup) export URL_BACKUP="$2"; shift 2;;
		  --restore) export URL_RESTORE="$2"; shift 2;;
		  
		  --os) export TARGET_SYSTEM="$2"; shift 2;;

		  --no-crypt) export CRYPTED="FALSE"; shift 1;;
		  --cipher) export CIPHER=" -c $2"; shift 2;;
		  
		  --hostname) export TARGET_HOSTNAME="$2"; shift 2;;
	  
		  --no-reboot) export AUTOREBOOT="FALSE"; shift 1;;
		  
		  --root-size) export ROOT_SIZE="$2"; shift 2;;
		  
		  --stop-at-base) export STOP_AT_INSTALL_BASE="TRUE"; shift 1;;

		  -*) echo "unknown option: $1" >&2; exit 1;;
		   *) echo "unknown option: $1" >&2; exit 1;;
	  esac
	done
}

function validateArguments {
	if [[ "${TARGET_SYSTEM^^}" != "DEBIAN" ]]; then
		echo "Only supported target system is debian at the moment"
		exit 1
	fi;

	if [[ -z "${TARGET_HOSTNAME}" ]]; then
	  echo "Please specify a hostname with --hostname HOSTNAME"
	  exit 1
	fi;
	
	TARGET_HOSTNAME_SHORT=`echo -n ${TARGET_HOSTNAME} | cut -d '.' -f 1`
	
	if [[ ! -z "${URL_BACKUP}" ]]; then
		URL_BACKUP=`echo ${URL_BACKUP} | sed -e "s/\%hostname\%/${TARGET_HOSTNAME_SHORT}/g"`
		URL_BACKUP_HOST=`echo -n ${URL_BACKUP} | cut -d '/' -f 3`
		URL_BACKUP_PATH=`echo -n ${URL_BACKUP} | cut -d '/' -f 4- | sed 's/\/$//g'`
		URL_BACKUP_PATH="/${URL_BACKUP_PATH}/"
		URL_BACKUP_USER=`echo -n ${TARGET_HOSTNAME} | cut -d '.' -f 1`
	fi;
	if [[ ! -z "${URL_RESTORE}" ]]; then
		URL_RESTORE=`echo ${URL_RESTORE} | sed -e "s/\%hostname\%/${TARGET_HOSTNAME_SHORT}/g"`
		URL_RESTORE_HOST=`echo -n ${URL_RESTORE} | cut -d '/' -f 3`
		URL_RESTORE_PATH=`echo -n ${URL_RESTORE} | cut -d '/' -f 4- | sed 's/\/$//g'`
		URL_RESTORE_PATH="/${URL_RESTORE_PATH}/"
		URL_RESTORE_USER=`echo -n ${TARGET_HOSTNAME} | cut -d '.' -f 1`
		
		echo "Testing SSH Connection"
		SSH_COMMAND="ssh -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${URL_RESTORE_USER}@${URL_RESTORE_HOST}"
		SSH_OK=$(${SSH_COMMAND} "ls -ls ${URL_RESTORE_PATH} &> /dev/null && echo YES")
		
		if ! isTrue "${SSH_OK}"; then
			chmod 600 /tmp/btrbk.identity
			SSH_COMMAND="ssh -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o IdentityFile=/tmp/btrbk.identity ${URL_RESTORE_USER}@${URL_RESTORE_HOST}"
			SSH_OK=$(${SSH_COMMAND} ${URL_RESTORE_USER}@${URL_RESTORE_HOST} "ls -ls ${URL_RESTORE_PATH} &> /dev/null && echo YES")
		fi;
		
		if ! isTrue "${SSH_OK}"; then
			echo SSH Connection is not working
			exit
		fi;
	fi;
	
	ROOT_BLOCK_SIZE="204800"
	if [[ ! -z "${ROOT_SIZE}" ]]; then
		ROOT_BLOCK_SIZE=`expr ${ROOT_SIZE} \* 1024 \* 2048`
	fi;
}

function isTrue {
	if [[ "${1^^}" = "YES" ]]; then return 0; fi;
	if [[ "${1^^}" = "TRUE" ]]; then return 0; fi;
	return 1;
}

function logLine {
	if isTrue "true"; then
        echo $@
	fi;
}

function detectSystem {
	IS_EFI="false"
	if [[ ! -d "/sys/firmware/efi" ]]; then
		logLine "BIOS DETECTED"
	else
		IS_EFI="true"
		DEV_ROOT_PART="3"
		logLine "EFI DETECTED"
	fi;
	
	if isTrue "${DEV_AUTO}"; then
		if [[ -b "/dev/sdd" ]]; then
			DEV_SRV="/dev/sdd"
		fi
		if [[ -b "/dev/sdc" ]]; then
			DEV_USR="/dev/sdc"
		fi
		if [[ -b "/dev/sdb" ]]; then
			DEV_VAR="/dev/sdb"
		fi
	fi;
}

function getSystemType {
  DISTIDENTIFIER=$(uname -m)
  if [[ "${DISTIDENTIFIER^^}" = "ARMV7L" ]]; then
    echo -n "ARMHF";
  else
    echo -n "AMD64";
  fi;
}

function getSystemName {
  SYSNAME=$(uname -a)
  if [[ "${SYSNAME^^}" = *"DEBIAN"* ]]; then
    echo -n "DEBIAN";
  elif [[ "${SYSNAME^^}" = *"ARCH"* ]]; then
    echo -n "ARCHLINUX";
  else
    echo -n "UNKNOWN";
  fi;
}

function installDependency {
	local SYSTEM_NAME=${1^^}
	local PACKAGE=${2}
	local CMD_NAME=${3}
	
	if [[ $(getSystemName) != "${SYSTEM_NAME}" ]]; then return 0; fi;
	
	if [[ $(getSystemName) = "DEBIAN" ]]; then
		if which ${CMD_NAME} > /dev/null; then
			return 1
		else
			echo Installing ${PACKAGE}...
			DEBIAN_FRONTEND=noninteractive apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${PACKAGE} -qq > /dev/null
		fi;
	fi;
	
	return -1;
}

function installDependencies {
	installDependency "DEBIAN" "debootstrap" "debootstrap"
	installDependency "DEBIAN" "parted" "parted"
	installDependency "DEBIAN" "arch-install-scripts" "genfstab"
	installDependency "DEBIAN" "btrfs-progs" "btrfs"
	installDependency "DEBIAN" "cryptsetup" "cryptsetup"
	installDependency "DEBIAN" "dosfstools" "mkfs.vfat"
	#installDependency "DEBIAN" "btrbk" "btrbk"
}

function cleanupOldMounts {
	umount -R /mnt/* &> /dev/null
	umount -R /mnt &> /dev/null
	umount -R /tmp/mnt/disks/* &> /dev/null
	sync
	
	rm -rf /tmp/mnt/disks/*
	
	cryptsetup --batch-mode close cryptroot &> /dev/null
	cryptsetup --batch-mode close crypthome &> /dev/null
	cryptsetup --batch-mode close cryptopt &> /dev/null
	cryptsetup --batch-mode close cryptsrv &> /dev/null
	cryptsetup --batch-mode close cryptusr &> /dev/null
	cryptsetup --batch-mode close cryptvar &> /dev/null
}

function formatDrive {
	for var in "$@"
	do
		local DEV="${var}"

		local dev_name=DEV_${DEV^^}
		local dev_name=${!dev_name}

		local dev_fs=DEV_${DEV^^}_FS
		local dev_fs=${!dev_fs}

		local dev_part=DEV_${DEV^^}_PART
		local dev_part=${!dev_part}
		
		if [[ -z "${dev_name}" ]]; then
			continue;
		fi;

		logLine "Partitioning ${dev_name}"
		
		if [[ "${var^^}" = "ROOT" ]]; then
			if isTrue "${IS_EFI^^}"; then
				sfdisk -q ${dev_name} &> /dev/null <<- EOM
label: gpt
unit: sectors

start=        2048, size=      204800, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="efi"
start=      206848, size=      512000, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="boot"
start=      718848, size=      ${ROOT_BLOCK_SIZE}, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="root"
EOM

				if [[ $? -ne 0 ]]; then
					echo "Failed to partition drive"
					exit 1
				fi;
				
				mkfs.vfat -F32 ${dev_name}1 &> /dev/null
				fatlabel ${dev_name} EFI &> /dev/null
				mkfs.ext2 -F -L boot ${dev_name}2 &> /dev/null
			else
				sfdisk -q ${dev_name} &> /dev/null <<- EOM
label: gpt
unit: sectors

start=2048, size=512000, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="boot"
start=514048, size=${ROOT_BLOCK_SIZE}, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="root"

EOM
				if [[ $? -ne 0 ]]; then
					echo "Failed to partition drive"
					exit 1
				fi;

				mkfs.ext2 -F -L boot ${dev_name}1 &> /dev/null
			fi;
			
			# Resize root if no size was specified
			if [[ -z "${ROOT_SIZE}" ]]; then
				parted ${dev_name} resizepart ${dev_part} 100%
			fi;
		else
			sfdisk -q ${dev_name} <<- EOM
label: gpt
unit: sectors

start=        2048, size=      204800, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="${DEV}"
EOM

			if [[ $? -ne 0 ]]; then
				echo "Failed to partition drive"
				exit 1
			fi;

			parted ${dev_name} resizepart ${dev_part} 100%
		fi;
		
		local FILESYSFORCE="-F"
		if [[ "${dev_fs^^}" = "BTRFS" ]]; then
			FILESYSFORCE="-f"
		fi;
		
		mkdir -p /tmp/mnt/disks/${var}
		if isTrue "${CRYPTED}"; then
			logLine "Encrypting ${dev_name}${dev_part}"
			
			cryptsetup --batch-mode luksFormat --type luks1 -d /tmp/cryptsetup.key${CIPHER} ${dev_name}${dev_part} &> /dev/null
			cryptsetup --batch-mode open ${dev_name}${dev_part} crypt${var} -d /tmp/cryptsetup.key &> /dev/null
			
			logLine "Formatting ${dev_name}"
			mkfs.${dev_fs} ${FILESYSFORCE} -L ${var} /dev/mapper/crypt${var} &> /dev/null
			mount /dev/mapper/crypt${var} /tmp/mnt/disks/${var}
		else
			logLine "Formatting ${dev_name}"
			mkfs.${dev_fs} ${FILESYSFORCE} -L ${var} ${dev_name}${dev_part} &> /dev/null
			mount ${dev_name}${dev_part} /tmp/mnt/disks/${var}
		fi;
		
		if [[ "${dev_fs^^}" = "BTRFS" ]]; then
			btrfs subvolume create /tmp/mnt/disks/${var}/data
			btrfs subvolume create /tmp/mnt/disks/${var}/snapshots
		fi;
		
		logLine "Prepared ${dev_name}"
	done
	
	sync
}

function mountDrive {
	for var in "$@"
	do
		local DEV="${var}"

		local dev_name=DEV_${DEV^^}
		local dev_name=${!dev_name}

		local dev_fs=DEV_${DEV^^}_FS
		local dev_fs=${!dev_fs}

		local dev_part=DEV_${DEV^^}_PART
		local dev_part=${!dev_part}
		
		local dev_path=DEV_${DEV^^}_PATH
		local dev_path=${!dev_path}
		
		if [[ -z "${dev_name}" ]]; then
			continue;
		fi;

		logLine "Mounting ${dev_name}"
		
		local mountOpts=""
		if [[ "${dev_fs^^}" = "BTRFS" ]]; then
			mountOpts="-o subvol=/data "
		fi;
		local mountDev="${dev_name}${dev_part}"
		if isTrue "${CRYPTED}"; then
			mountDev="/dev/mapper/crypt${var}"
		fi;
		
		if [[ "${var^^}" = "ROOT" ]]; then
			mount ${mountOpts}${mountDev} /mnt
			
			if [[ "${dev_fs^^}" = "BTRFS" ]]; then
				mkdir -p /mnt/mnt/disks/${var} &> /dev/null
				mount -o subvol=/ ${mountDev} /mnt/mnt/disks/${var}
			fi;
		
			if isTrue "${IS_EFI^^}"; then
				mkdir -p /mnt/boot &> /dev/null
				mount ${dev_name}2 /mnt/boot
				mkdir -p /mnt/boot/efi &> /dev/null
				mount ${dev_name}1 /mnt/boot/efi
			else
				mkdir -p /mnt/boot &> /dev/null
				mount ${dev_name}1 /mnt/boot
			fi;
		else
			if [[ -z "${dev_path}" ]]; then
				mkdir /mnt/${var} &> /dev/null
				mount ${mountOpts}${mountDev} /mnt/${var}
			else
				mkdir -p /mnt/${dev_path} &> /dev/null
				mount ${mountOpts}${mountDev} /mnt/${dev_path}
			fi;
			
			if [[ "${dev_fs^^}" = "BTRFS" ]]; then
				mkdir -p /mnt/mnt/disks/${var} &> /dev/null
				mount -o subvol=/ ${mountDev} /mnt/mnt/disks/${var}
			fi;
		fi;
	done
}

function prepareChroot {
	# Additional Mounts for chroot
	mount -t proc proc /mnt/proc/
	mount -t sysfs sys /mnt/sys/
	mount -t devtmpfs dev /mnt/dev/
	mount -t devpts devpts /mnt/dev/pts
	if [[ "${IS_EFI^^}" = "YES" ]]; then
		mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars
	fi;

	# Mount TMP
	mkdir -p /mnt/tmp
	mount -t tmpfs tmpfs /mnt/tmp
	
	# Enable Systemd-Networkd resolv.conf
	rm -f /mnt/etc/resolv.conf
	cp /etc/resolv.conf /mnt/etc/resolv.conf
}

function restoreBackup {
	for var in "$@"
	do
		local DEV="${var}"

		local dev_name=DEV_${DEV^^}
		local dev_name=${!dev_name}

		local dev_fs=DEV_${DEV^^}_FS
		local dev_fs=${!dev_fs}

		local dev_part=DEV_${DEV^^}_PART
		local dev_part=${!dev_part}
		
		if [[ -z "${dev_name}" ]]; then
			continue;
		fi;
		
		echo "Restoring ${var} to ${dev_name}"
		backupFiles=$(${SSH_COMMAND} "find ${URL_RESTORE_PATH} -name '${var}.*.btrfs.xz'" 2> /dev/null | sort | awk '{ print length, $0 }' | sort -n -s | cut -d" " -f2-)
		LASTFILE=""
		for file in ${backupFiles}
		do
			LASTFILE=$(basename ${file} | rev | cut -d '.' -f 3- | rev)
			logLine Restoring ${file}
			${SSH_COMMAND} "cat ${file}" 2> /dev/null | xz -d -c | btrfs receive /tmp/mnt/disks/${var}
		done
  
		btrfs subvolume delete /tmp/mnt/disks/${var}/data
		btrfs subvolume snapshot /tmp/mnt/disks/${var}/${LASTFILE} /tmp/mnt/disks/${var}/data
  
		for file in ${backupFiles}
		do
			# Cleanup
			SNAP=$(basename ${file} | rev | cut -d '.' -f 3- | rev)
			btrfs subvolume delete /tmp/mnt/disks/${var}/${SNAP}
		done
	done
}

function installGrub {
	cat > /mnt/chroot.sh <<- EOM
#!/bin/bash
. /etc/profile
EOM
	chmod +x /mnt/chroot.sh
	
	if [[ "${TARGET_SYSTEM^^}" = "DEBIAN" ]]; then
		if [[ ( $(getSystemType) = "ARMHF" ) ]]; then
			echo WILL USE GRUB-EFI-ARM
			echo "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq grub-efi-arm" >> /mnt/chroot.sh
			echo "grub-install --removable --target=arm-efi --boot-directory=/boot --efi-directory=/boot/efi" >> /mnt/chroot.sh
		else
			echo WILL USE GRUB-EFI
			echo "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq grub-efi" >> /mnt/chroot.sh
			echo "grub-install --target=x86_64-efi --boot-directory=/boot --efi-directory=/boot/efi" >> /mnt/chroot.sh
		fi;
	fi;
	
	echo "update-initramfs -k all -u" >> /mnt/chroot.sh
	echo "grub-mkconfig -o /boot/grub/grub.cfg" >> /mnt/chroot.sh
	chroot /mnt /chroot.sh
	rm /mnt/chroot.sh
}

function restoreResolve {
	cat > /mnt/chroot.sh <<- 'EOF'
#!/bin/bash
. /etc/profile
rm -f /etc/resolv.conf
ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
EOF
	chmod +x /mnt/chroot.sh
	chroot /mnt /chroot.sh
	rm /mnt/chroot.sh
}

function installDebian {
	cat > /mnt/chroot.sh <<- 'EOF'
#!/bin/bash
. /etc/profile

DEBIAN_FRONTEND=noninteractive apt-get update -qq
echo -e "root\nroot" | passwd root

DEBIAN_FRONTEND=noninteractive apt-get install -y -qq locales console-data dirmngr btrfs-progs btrbk
sed -i '/de_DE.UTF-8/s/^#//' /etc/locale.gen
sed -i '/en_US.UTF-8/s/^#//' /etc/locale.gen
locale-gen
echo -e 'LANG="en_US.UTF-8"\nLANGUAGE="en_US.UTF-8"\nLC_ALL="en_US.UTF-8"\n' > /etc/default/locale

echo "btrfs" >> /etc/initramfs-tools/modules

systemctl enable systemd-networkd
systemctl enable systemd-resolved

DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openssh-server
sed -i 's/^#PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config

EOF

	# Install Kernel
	if [[ ( $(getSystemType) = "ARMHF" ) ]]; then
		echo "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq linux-image-armmp-lpae" >> /mnt/chroot.sh
	else
		echo "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq linux-image-amd64" >> /mnt/chroot.sh
	fi;

	# Crypted?
	if isTrue "${CRYPTED}"; then
		# Install cryptsetup & dropbear
		echo "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq cryptsetup dropbear-initramfs" >> /mnt/chroot.sh

		# Also create crypttab
		echo "echo cryptroot PARTLABEL=root none luks > /etc/crypttab" >> /mnt/chroot.sh
		if [[ ! -z "${DEV_HOME}" ]]; then echo "echo crypthome PARTLABEL=home /etc/crypt.key luks >> /etc/crypttab" >> /mnt/chroot.sh; fi;
		if [[ ! -z "${DEV_OPT}" ]];  then echo "echo cryptopt PARTLABEL=opt /etc/crypt.key luks >> /etc/crypttab" >> /mnt/chroot.sh; fi;
		if [[ ! -z "${DEV_SRV}" ]];  then echo "echo cryptsrv PARTLABEL=srv /etc/crypt.key luks >> /etc/crypttab" >> /mnt/chroot.sh; fi;
		if [[ ! -z "${DEV_USR}" ]];  then echo "echo cryptusr PARTLABEL=usr /etc/crypt.key luks >> /etc/crypttab" >> /mnt/chroot.sh; fi;
		if [[ ! -z "${DEV_VAR}" ]];  then echo "echo cryptvar PARTLABEL=var /etc/crypt.key luks >> /etc/crypttab" >> /mnt/chroot.sh; fi;
	fi;

	# Run Script
	chmod +x /mnt/chroot.sh
	chroot /mnt /chroot.sh
	rm /mnt/chroot.sh

	# Setup Network
	rm -f /mnt/etc/network/interfaces
	rm -f /mnt/etc/network/interfaces.d/*
	cat > /mnt/etc/systemd/network/en.network <<- EOM
[Match]
Name=en*

[Network]
DHCP=yes
EOM
	cat > /mnt/etc/systemd/network/eth.network <<- EOM
[Match]
Name=eth*

[Network]
DHCP=yes
EOM
}

function setupBtrbk {
	rm -f /mnt/etc/btrbk/${TARGET_HOSTNAME_SHORT}.key &> /dev/null
	rm -f /mnt/etc/btrbk/${TARGET_HOSTNAME_SHORT}.key.pub &> /dev/null
	ssh-keygen -t ed25519 -N '' -C "btrbk-backup-key@hostname" -f /mnt/etc/btrbk/${TARGET_HOSTNAME_SHORT}.key &> /dev/null
	chown root:root /mnt/etc/btrbk/${TARGET_HOSTNAME_SHORT}.key
	chmod 0600 /mnt/etc/btrbk/${TARGET_HOSTNAME_SHORT}.key

	cat > /mnt/etc/cron.daily/btrbk <<- EOF
#!/bin/sh

/usr/sbin/btrbk run
EOF
	chown root:root /mnt/etc/cron.daily/btrbk
	chmod 0755 /mnt/etc/cron.daily/btrbk
	
	cat > /mnt/etc/btrbk/btrbk.conf <<- EOF
snapshot_dir snapshots

snapshot_preserve_min latest
snapshot_preserve 0h

raw_target_compress   xz

ssh_user ${TARGET_HOSTNAME_SHORT}
ssh_identity /etc/btrbk/${TARGET_HOSTNAME_SHORT}.key

target raw ssh://${URL_BACKUP_HOST}${URL_BACKUP_PATH}

EOF

	for var in "$@"
	do
		local DEV="${var}"

		local dev_name=DEV_${DEV^^}
		local dev_name=${!dev_name}

		local dev_fs=DEV_${DEV^^}_FS
		local dev_fs=${!dev_fs}

		local dev_part=DEV_${DEV^^}_PART
		local dev_part=${!dev_part}
		
		if [[ -z "${dev_name}" ]]; then
			continue;
		fi;

		cat >> /mnt/etc/btrbk/btrbk.conf <<- EOM
volume /mnt/disks/${var}
        subvolume data
                snapshot_name ${var}
EOM
	done
}

function installCryptoKey {
	# Save key on root drive to unlock other drives
	if isTrue "${CRYPTED}"; then
		cp /tmp/cryptsetup.key /mnt/etc/crypt.key
		chown root:root /mnt/etc/crypt.key
		chmod 600 /mnt/etc/crypt.key
	fi;
}

function fixFSTab {
	sed -i 's/,subvolid=[0-9]*//g' /mnt/etc/fstab
}

parseArguments $@
validateArguments
detectSystem
installDependencies
cleanupOldMounts

if isTrue "${CRYPTED}"; then
	rm -f /tmp/cryptsetup.key &> /dev/null
	dd if=/dev/urandom of=/tmp/cryptsetup.key bs=1024 count=1
fi;

formatDrive "root"

# Add Password for root
if isTrue "${CRYPTED}"; then
	logLine "Setting default password test1234 for root device"
	echo test1234 | cryptsetup --batch-mode luksAddKey ${DEV_ROOT}${DEV_ROOT_PART} -d /tmp/cryptsetup.key
fi;

if [[ ! -z "${URL_RESTORE}" ]]; then
	logLine "Restoring from ${URL_RESTORE}"
	restoreBackup "root"
	mountDrive "root"

	# Check if there are enough drives for restore
	driveCount=$(find /dev -name 'sd*' | grep -v '[0-9]$' | wc -l)
	totalDrives=$(cat /mnt/etc/fstab | grep /mnt/disks | grep btrfs | awk '{ print $1 }' | wc -l)
	while [[ "${driveCount}" -gt "${totalDrives}" ]];
	do
		echo "Not enough Harddisks found for restore, please add another one"
		read -p "Press enter to continue"
	done
	
	# Prepare Variables for additional Drives
	driveCount="0"
	additionalDrives=$(cat /mnt/etc/fstab | grep /mnt/disks | grep btrfs | grep -v '^LABEL\=root' | awk '{ print length($2), $0 }' | sort -n -s | cut -d" " -f2 | cut -d '=' -f 2- | grep -v 'srv' | grep -v 'var' | grep -v 'usr' | grep -v 'home' | grep -v 'opt')
	for addDrive in "${additionalDrives}"
	do
		driveCount=$((driveCount + 1))
		targetDrive=$(find /dev -name 'sd*' | grep -v '[0-9]$' | sort | tail -${driveCount} | head -1)
		targetDir=$(cat /mnt/etc/fstab | grep -v /mnt/disks | grep btrfs | grep "LABEL\=cloud" | awk '{ print $2 }')
		
		declare DEV_${addDrive^^}="${targetDrive}"
		declare DEV_${addDrive^^}_PATH="${targetDir}"
		declare DEV_${addDrive^^}_FS="btrfs"
		declare DEV_${addDrive^^}_PART="1"
	done
	
	# Restore normal drives
	formatDrive "home" "opt" "srv" "usr" "var"
	restoreBackup "home" "opt" "srv" "usr" "var"
	mountDrive "home" "opt" "srv" "usr" "var"
	
	# Restore additional drives
	for addDrive in "${additionalDrives}"
	do
		formatDrive "${addDrive}"
		restoreBackup "${addDrive}"
		
		# Cleanup Custom drive
		umount /tmp/mnt/disks/${addDrive}
		
		if isTrue "${CRYPTED}"; then
			cryptsetup --batch-mode close crypt${addDrive} &> /dev/null
			
			# Ensure crypttab is complete
			grep -qxF "crypt${addDrive}" /mnt/etc/crypttab || echo "crypt${addDrive} PARTLABEL=${addDrive} /etc/crypt.key luks" >> /mnt/etc/crypttab
		fi;
		
		rm -rf /tmp/mnt/disks/${addDrive}
	done
	
	# Save key on root drive to unlock other drives
	installCryptoKey
	
	# Fix fstab
	fixFSTab
	
	# Reinstall Kernel to restore /boot
	prepareChroot
	cat > /mnt/chroot.sh <<- 'EOF'
#!/bin/bash
. /etc/profile
dpkg -l | grep linux-image- | grep -v 'meta' | sort -k3 | tail -n1 | awk '{system ("apt-get install --reinstall " $2)}'

EOF
	chmod +x /mnt/chroot.sh
	chroot /mnt /chroot.sh
	rm /mnt/chroot.sh
	
	# Install Grub
	installGrub
	
	# Restore resolv.conf
	restoreResolve
	
	if [[ "${AUTOREBOOT^^}" = "YES" ]]; then
		cleanupOldMounts
		echo "All Done, rebooting"
		reboot now
	fi;

	echo "All Done, please reboot"
	exit
fi;

formatDrive "home" "opt" "srv" "usr" "var"
mountDrive "root" "home" "opt" "srv" "usr" "var"

logLine "Debootstrapping"
debootstrap stable /mnt http://ftp.de.debian.org/debian/;
genfstab -pL /mnt >> /mnt/etc/fstab
echo -n "${TARGET_HOSTNAME}" > /mnt/etc/hostname

# Save key on root drive to unlock other drives
installCryptoKey

# Fix fstab
fixFSTab

# Prepare Chroot
prepareChroot

# Install Debian
installDebian

# Setup BTRBK
setupBtrbk "root" "home" "opt" "srv" "usr" "var"

# Install Grub
installGrub

# Restore resolv.conf
restoreResolve

# Done
if [[ "${AUTOREBOOT^^}" = "YES" ]]; then
	cleanupOldMounts
	echo "All Done, rebooting"
	reboot now
fi;

echo "All Done, please reboot"
