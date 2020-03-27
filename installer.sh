#!/bin/bash

# Parse arguments
CRYPTED=""
TARGET_SYSTEM="DEBIAN"

DEV_ROOT="/dev/sda"
DEV_ROOT_FS="ext4"

DEV_HOME=""
DEV_HOME_FS="ext4"

DEV_OPT=""
DEV_OPT_FS="ext4"

DEV_SRV=""
DEV_SRV_FS="ext4"

DEV_USR=""
DEV_USR_FS="ext4"

DEV_VAR=""
DEV_VAR_FS="ext4"

DEV_BACKUP=""
DEV_BACKUP_FS="btrfs"

FILESYS="btrfs"
VERBOSE=""
TARGET_HOSTNAME=""

ANSIBLE_PULL_REPO=""

AUTOREBOOT="yes"

IS_EFI="yes"
ROOT_SIZE=""
STOP_AT_INSTALL_BASE=""
CIPHER=""

while [ "$#" -gt 0 ]; do
  case "$1" in
      --verbose) export VERBOSE=" --verbose"; shift 1;;
      --system) export TARGET_SYSTEM="$2"; shift 2;;
      
      --fs) export DEV_ROOT_FS="$2"; export export DEV_HOME_FS="$2"; export DEV_OPT_FS="$2"; export DEV_SRV_FS="$2"; export DEV_USR_FS="$2"; export DEV_VAR_FS="$2"; shift 2;;

      --root) export DEV_ROOT="$2"; shift 2;;
      --root-fs) export DEV_ROOT_FS="$2"; shift 2;;

      --home) export DEV_HOME="$2"; shift 2;;
      --home-fs) export DEV_HOME_FS="$2"; shift 2;;

      --opt) export DEV_OPT="$2"; shift 2;;
      --opt-fs) export DEV_OPT_FS="$2"; shift 2;;

      --srv) export DEV_SRV="$2"; shift 2;;
      --srv-fs) export DEV_SRV_FS="$2"; shift 2;;

      --usr) export DEV_USR="$2"; shift 2;;
      --usr-fs) export DEV_USR_FS="$2"; shift 2;;

      --var) export DEV_VAR="$2"; shift 2;;
      --var-fs) export DEV_VAR_FS="$2"; shift 2;;
	  
	  --backup) export DEV_BACKUP="$2"; shift 2;;
	  
	  --os) export TARGET_SYSTEM="$2"; shift 2;;

      --crypt) export CRYPTED="true"; shift 1;;
	  --cipher) export CIPHER="$2"; shift 2;;
	  
      --hostname) export TARGET_HOSTNAME="$2"; shift 2;;

      --pullrepo) export ANSIBLE_PULL_REPO="$2"; shift 2;;
	  
	  --no-reboot) export AUTOREBOOT="no"; shift 1;;
	  
	  --root-size) export ROOT_SIZE="$2"; shift 2;;
	  
	  --stop-at-base) export STOP_AT_INSTALL_BASE="YES"; shift 1;;

      -*) echo "unknown option: $1" >&2; exit 1;;
       *) echo "unknown option: $1" >&2; exit 1;;
  esac
done

function getSystemType {
  DISTIDENTIFIER=`uname -m`
  if [ "${DISTIDENTIFIER^^}" = "ARMV7L" ]; then
    echo -n "ARMHF";
  else
    echo -n "AMD64";
  fi;
}

function getSystemName {
  SYSNAME=`uname -a`
  if [[ "${SYSNAME^^}" = *"DEBIAN"* ]]; then
    echo -n "DEBIAN";
  elif [[ "${SYSNAME^^}" = *"ARCH"* ]]; then
    echo -n "ARCHLINUX";
  else
    echo -n "UNKNOWN";
  fi;
}

function installPackage {
  if [[ ( "${3}" != "" ) && ( "${2}" = "" || $(getSystemName) == "${2^^}" ) ]]; then
    EXISTS=`type ${3} >/dev/null 2>&1 || echo "Not Installed"`
    if [[ "${EXISTS}" = "" ]]; then
      echo ${1} is already installed...
      return 0
    fi;
  fi;

  if [[ ( "${2}" = "" && $(getSystemName) = "DEBIAN" ) || ( $(getSystemName) == "${2^^}" ) ]]; then
    echo Installing ${1}...
    DEBIAN_FRONTEND=noninteractive apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $1 -qq > /dev/null
  fi;

  if [[ ( "${2}" = "" && $(getSystemName) = "ARCHLINUX" ) || ( $(getSystemName) == "${2^^}" ) ]]; then
    echo Installing ${1}...
    pacman -Sy --noconfirm ${1}
  fi;

  return 0
}

function formatPartition {
  FILESYSFORCE="-F"
  if [[ "${3^^}" = "BTRFS" ]]; then
    FILESYSFORCE="-f"
  fi;

  if [[ "${4^^}" = "TRUE" ]]; then
    if [[ ! -z "${6}" ]]; then
	  if [[ ! -z "${5}" ]]; then
        cryptsetup --batch-mode luksFormat --type luks1 -c ${5} ${1} -d ${6}
        cryptsetup --batch-mode open ${1} crypt${2} -d ${6}
	  else
        cryptsetup --batch-mode luksFormat --type luks1 ${1} -d ${6}
        cryptsetup --batch-mode open ${1} crypt${2} -d ${6}	  
	  fi;
    else
	  if [[ ! -z "${5}" ]]; then
        echo test1234 | cryptsetup --batch-mode luksFormat --type luks1 -c ${5} ${1}
        echo test1234 | cryptsetup --batch-mode open ${1} crypt${2}
	  else
        echo test1234 | cryptsetup --batch-mode luksFormat --type luks1 ${1}
        echo test1234 | cryptsetup --batch-mode open ${1} crypt${2}
	  fi;
    fi;

    mkfs.${3,,} ${FILESYSFORCE} -L ${2} /dev/mapper/crypt${2}
    sync
  else
    mkfs.${3,,} ${FILESYSFORCE} -L ${2} ${1}
    sync
  fi;


  if [[ "${3^^}" = "BTRFS" ]]; then
    mkdir -p /tmp/btrfs/${2}

    if [[ "${4^^}" = "TRUE" ]]; then
      mount /dev/mapper/crypt${2} /tmp/btrfs/${2}
    else
      mount ${1} /tmp/btrfs/${2}
    fi;
    btrfs subvol create /tmp/btrfs/${2}/data
    #btrfs subvol set-default `btrfs subvol list /tmp/btrfs/${2} | grep data | cut -d' ' -f2` /tmp/btrfs/${2}
    sync
    umount /tmp/btrfs/${2}
    sync
  fi;
}

function formatDrive {
  sfdisk ${1} <<- EOM
label: gpt
unit: sectors

start=        2048, size=      204800, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="${2}"
EOM
  sync

  # Resize Root Partition
  parted ${1} resizepart 1 100%
  sync

  # Create Filesystem
  if [[ "${4^^}" = "TRUE" ]]; then
    formatPartition ${1}1 ${2} ${3} ${4} ${5} /mnt/crypt.key
  else
    formatPartition ${1}1 ${2} ${3} ${4} ${5}
  fi;

  # Mount
  mkdir /mnt/${2}
  
  if [[ "${4^^}" = "TRUE" ]]; then
	if [[ "${3^^}" = "BTRFS" ]]; then
		mount -o subvol=data /dev/mapper/crypt${2} /mnt/${2}
	else
		mount /dev/mapper/crypt${2} /mnt/${2}
	fi;
  else
	if [[ "${3^^}" = "BTRFS" ]]; then
		mount -o subvol=data ${1}1 /mnt/${2}
	else
		mount ${1}1 /mnt/${2}
	fi;
  fi;

  sync
}

if [[ ! -d "/sys/firmware/efi" ]]; then
  IS_EFI="no"
  echo "BIOS DETECTED"
  #exit 1
else
  echo "EFI DETECTED"
fi;

if [[ "${TARGET_SYSTEM^^}" != "DEBIAN" ]]; then
  if [[ "${TARGET_SYSTEM^^}" != "ARCH" ]]; then
    echo "Only supported target system is arch and debian atm"
    exit 1
  fi;
fi;

if [[ -z "${TARGET_HOSTNAME}" ]]; then
  echo "Please specify a hostname with --hostname HOSTNAME"
  exit 1
fi;

if [[ "${TARGET_SYSTEM^^}" = "DEBIAN" ]]; then
  installPackage debootstrap "" debootstrap;
fi;

if [[ "${TARGET_SYSTEM^^}" = "ARCH" ]]; then
  installPackage pacstrap "" pacstrap;
fi;

installPackage parted "" parted;

# Format Disk
ROOT_BLOCK_SIZE="204800"
if [[ ! -z "${ROOT_SIZE}" ]]; then
  ROOT_BLOCK_SIZE=`expr ${ROOT_SIZE} \* 1024 \* 2048`
fi;

if [[ "${IS_EFI^^}" = "YES" ]]; then
	ROOT_PART_NUM="3"
	echo <<- EOM
label: gpt
unit: sectors

start=        2048, size=      204800, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="efi"
start=      206848, size=      512000, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="boot"
start=      718848, size=      ${ROOT_BLOCK_SIZE}, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="root"
EOM
	sfdisk ${DEV_ROOT} <<- EOM
label: gpt
unit: sectors

start=        2048, size=      204800, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="efi"
start=      206848, size=      512000, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="boot"
start=      718848, size=      ${ROOT_BLOCK_SIZE}, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="root"
EOM
fi;

if [[ "${IS_EFI^^}" = "NO" ]]; then
	ROOT_PART_NUM="2"
	echo <<- EOM
label: gpt
unit: sectors

start=2048, size=512000, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="boot"
start=514048, size=${ROOT_BLOCK_SIZE}, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="root"

EOM
	sfdisk ${DEV_ROOT} <<- EOM
label: gpt
unit: sectors

start=2048, size=512000, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="boot"
start=514048, size=${ROOT_BLOCK_SIZE}, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="root"

EOM
fi;
sync

# Resize Root Partition
if [[ -z "${ROOT_SIZE}" ]]; then
  parted ${DEV_ROOT} resizepart ${ROOT_PART_NUM} 100%
fi;


sync

# Create Filesystems
if [[ "${IS_EFI^^}" = "YES" ]]; then
	mkfs.vfat -F32 ${DEV_ROOT}1
	fatlabel ${DEV_ROOT} EFI
	mkfs.ext2 -F -L boot ${DEV_ROOT}2
else
	mkfs.ext2 -F -L boot ${DEV_ROOT}1
	
fi;

formatPartition ${DEV_ROOT}${ROOT_PART_NUM} root ${DEV_ROOT_FS} ${CRYPTED} ${CIPHER}
sync

# Mount Root
if [[ "${CRYPTED^^}" = "TRUE" ]]; then
  mount /dev/mapper/cryptroot /mnt
else
  mount ${DEV_ROOT}${ROOT_PART_NUM} /mnt
fi;

# Mount Boot and Efi
if [[ "${IS_EFI^^}" = "YES" ]]; then
	mkdir /mnt/boot
	mount ${DEV_ROOT}2 /mnt/boot
	mkdir /mnt/boot/efi
	mount ${DEV_ROOT}1 /mnt/boot/efi
else
	mkdir /mnt/boot
	mount ${DEV_ROOT}1 /mnt/boot
fi;
sync

# Generate a key file
if [[ "${CRYPTED^^}" = "TRUE" ]]; then
  dd if=/dev/urandom of=/mnt/crypt.key bs=1024 count=1
  echo test1234 | cryptsetup --batch-mode luksAddKey ${DEV_ROOT}${ROOT_PART_NUM} /mnt/crypt.key
fi;

# Format Additional Partitions?
if [[ ! -z "${DEV_HOME}" ]];    then formatDrive ${DEV_HOME} home ${DEV_HOME_FS} ${CRYPTED} ${CIPHER}; fi;
if [[ ! -z "${DEV_OPT}" ]];     then formatDrive ${DEV_OPT} opt ${DEV_OPT_FS} ${CRYPTED} ${CIPHER}; fi;
if [[ ! -z "${DEV_SRV}" ]];     then formatDrive ${DEV_SRV} srv ${DEV_SRV_FS} ${CRYPTED} ${CIPHER}; fi;
if [[ ! -z "${DEV_USR}" ]];     then formatDrive ${DEV_USR} usr ${DEV_USR_FS} ${CRYPTED} ${CIPHER}; fi;
if [[ ! -z "${DEV_VAR}" ]];     then formatDrive ${DEV_VAR} var ${DEV_VAR_FS} ${CRYPTED} ${CIPHER}; fi;
if [[ ! -z "${DEV_BACKUP}" ]];  then formatDrive ${DEV_BACKUP} backup ${DEV_BACKUP_FS} ${CRYPTED} ${CIPHER}; fi;

if [[ ! -z "${STOP_AT_INSTALL_BASE}" ]]; then
	exit
fi;

# Install Base to /mnt
echo "Installing Base System..."

# Install Strap
if [[ "${TARGET_SYSTEM^^}" = "ARCH" ]]; then
  pacstrap /mnt base linux linux-firmware
elif [[ "${TARGET_SYSTEM^^}" = "DEBIAN" ]]; then
  debootstrap stable /mnt http://ftp.de.debian.org/debian/;
else
  echo "Could not install system"
  exit 1
fi;

# Additional Mounts for chroot
echo "Mountint additional Mounts";
mount -t proc proc /mnt/proc/
mount -t sysfs sys /mnt/sys/
mount -t devtmpfs dev /mnt/dev/
mount -t devpts devpts /mnt/dev/pts
mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars

# Mount TMP
mkdir -p /mnt/tmp
mount -t tmpfs tmpfs /mnt/tmp

function createBackupMountPoint {
  if [[ ! -z "${1}" && "${2^^}" = "BTRFS" ]]; then
	mkdir -p /mnt/mnt/disks/${4}
	
	if [[ "${5^^}" = "TRUE" ]]; then
	    mount -o subvolid=5 /dev/mapper/crypt${4} /mnt/mnt/disks/${4}
	else
		mount -o subvolid=5 ${1}${3} /mnt/mnt/disks/${4}
	fi;
	
	btrfs subvolume create /mnt/mnt/disks/${4}/snapshots
	cat >> /mnt/etc/btrbk/btrbk.conf <<- EOM
volume /mnt/disks/${4}
        subvolume data
                snapshot_name ${4}

EOM
  fi;
}
if [[ ! -z "${DEV_BACKUP}" ]];  then
  mkdir -p /mnt/mnt/disks
  
  mkdir -p /mnt/etc/btrbk/
  cat > /mnt/etc/btrbk/btrbk.conf <<- EOM
snapshot_dir snapshots

snapshot_preserve_min latest
snapshot_preserve 0h

raw_target_compress   xz
#raw_target_encrypt    gpg

#gpg_keyring           /etc/btrbk/gpg/pubring.gpg
#gpg_recipient         btrbk@mydomain.com

target raw /backup

EOM
  
  # Mount root for backups
  createBackupMountPoint ${DEV_ROOT} ${DEV_ROOT_FS} 3 root ${CRYPTED}
  createBackupMountPoint ${DEV_HOME} ${DEV_HOME_FS} 1 home ${CRYPTED}
  createBackupMountPoint ${DEV_OPT} ${DEV_OPT_FS} 1 opt ${CRYPTED}
  createBackupMountPoint ${DEV_SRV} ${DEV_SRV_FS} 1 srv ${CRYPTED}
  createBackupMountPoint ${DEV_USR} ${DEV_USR_FS} 1 usr ${CRYPTED}
  createBackupMountPoint ${DEV_VAR} ${DEV_VAR_FS} 1 var ${CRYPTED}
fi;

# Generate fstab
genfstab -pL /mnt >> /mnt/etc/fstab

# Setup Network
# Disable old interfaces
rm -f /mnt/etc/network/interfaces
rm -f /mnt/etc/network/interfaces.d/*

# Enable Systemd-Networkd resolv.conf
rm -f /mnt/etc/resolv.conf
cp /etc/resolv.conf /mnt/etc/resolv.conf

# Setup Systemd-Networkd interface
cat > /mnt/etc/systemd/network/en.network <<- EOM
[Match]
Name=en*

[Network]
DHCP=yes
EOM

cat > /mnt/etc/systemd/network/eth0.network <<- EOM
[Match]
Name=eth0

[Network]
DHCP=yes
EOM

cat > /mnt/etc/systemd/network/ens192.network <<- EOM
[Match]
Name=ens192

[Network]
DHCP=yes
EOM

# Setup Hostname
echo "${TARGET_HOSTNAME}" > /mnt/etc/hostname

# Script Header
cat > /mnt/chrootinit.sh <<- EOM
#!/bin/bash
. /etc/profile
EOM

# Update System
if [[ "${TARGET_SYSTEM^^}" = "ARCH" ]]; then
  cat >> /mnt/chrootinit.sh <<- EOM
pacman -Syu --noconfirm
EOM
fi;

if [[ "${TARGET_SYSTEM^^}" = "DEBIAN" ]]; then
  cat >> /mnt/chrootinit.sh <<- EOM
DEBIAN_FRONTEND=noninteractive apt-get update -qq
EOM
fi;

# Install Locales
if [[ "${TARGET_SYSTEM^^}" = "ARCH" ]]; then
  cat >> /mnt/chrootinit.sh <<- EOM
sed -i '/de_DE.UTF-8/s/^#//' /etc/locale.gen
sed -i '/en_US.UTF-8/s/^#//' /etc/locale.gen
locale-gen
localectl set-locale LANG=en_US.UTF-8
EOM
fi;

if [[ "${TARGET_SYSTEM^^}" = "DEBIAN" ]]; then
  cat >> /mnt/chrootinit.sh <<- EOM
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq locales console-data dirmngr
sed -i '/de_DE.UTF-8/s/^#//' /etc/locale.gen
sed -i '/en_US.UTF-8/s/^#//' /etc/locale.gen
locale-gen
echo -e 'LANG="en_US.UTF-8"\nLANGUAGE="en_US.UTF-8"\nLC_ALL="en_US.UTF-8"\n' > /etc/default/locale
EOM
fi;

# Set Root Password
cat >> /mnt/chrootinit.sh <<- EOM
echo -e "root\nroot" | passwd root
EOM

# Install linux-image
if [[ "${TARGET_SYSTEM^^}" = "DEBIAN" ]]; then
  cat >> /mnt/chrootinit.sh <<- EOM
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq linux-image-amd64
EOM
fi;

if [[ "${DEV_ROOT_FS^^}${DEV_HOME_FS^^}${DEV_OPT_FS^^}${DEV_SRV_FS^^}${DEV_USR_FS^^}${DEV_VAR_FS^^}" == *"BTRFS"* ]]; then
  if [[ "${TARGET_SYSTEM^^}" = "ARCH" ]]; then
    cat >> /mnt/chrootinit.sh <<- EOM
pacman -Sy --noconfirm btrfs-progs
EOM
  fi;
  if [[ "${TARGET_SYSTEM^^}" = "DEBIAN" ]]; then
    cat >> /mnt/chrootinit.sh <<- EOM
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq btrfs-progs
EOM
  fi;
fi;

# Install Bootloader
if [[ "${TARGET_SYSTEM^^}" = "ARCH" ]]; then
  cat >> /mnt/chrootinit.sh <<- EOM
pacman -Sy --noconfirm efibootmgr grub
grub-install
grub-mkconfig -o /boot/grub/grub.cfg
EOM
fi;

if [[ "${TARGET_SYSTEM^^}" = "DEBIAN" ]]; then
  cat >> /mnt/chrootinit.sh <<- EOM
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq grub2-common grub-efi
grub-install
grub-mkconfig -o /boot/grub/grub.cfg
EOM
fi;

if [[ "${CRYPTED^^}" = "TRUE" ]]; then
  # Install cryptsetup and dropbear
  cat >> /mnt/chrootinit.sh <<- EOM
mv /crypt.key /etc/crypt.key
chown root:root /etc/crypt.key
chmod 600 /etc/crypt.key
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq cryptsetup #dropbear-initramfs
echo cryptroot PARTLABEL=root none luks > /etc/crypttab
EOM

  # Additional Drives?
  if [[ ! -z "${DEV_HOME}" ]]; then echo "echo crypthome PARTLABEL=home /etc/crypt.key luks >> /etc/crypttab" >> /mnt/chrootinit.sh; fi;
  if [[ ! -z "${DEV_OPT}" ]];  then echo "echo cryptopt PARTLABEL=opt /etc/crypt.key luks >> /etc/crypttab" >> /mnt/chrootinit.sh; fi;
  if [[ ! -z "${DEV_SRV}" ]];  then echo "echo cryptsrv PARTLABEL=srv /etc/crypt.key luks >> /etc/crypttab" >> /mnt/chrootinit.sh; fi;
  if [[ ! -z "${DEV_USR}" ]];  then echo "echo cryptusr PARTLABEL=usr /etc/crypt.key luks >> /etc/crypttab" >> /mnt/chrootinit.sh; fi;
  if [[ ! -z "${DEV_VAR}" ]];  then echo "echo cryptvar PARTLABEL=var /etc/crypt.key luks >> /etc/crypttab" >> /mnt/chrootinit.sh; fi;
  if [[ ! -z "${DEV_BACKUP}" ]];  then echo "echo cryptbackup PARTLABEL=backup /etc/crypt.key luks >> /etc/crypttab" >> /mnt/chrootinit.sh; fi;

  # Setup btrfs module for initramfs
  if [[ "${DEV_ROOT_FS^^}${DEV_HOME_FS^^}${DEV_OPT_FS^^}${DEV_SRV_FS^^}${DEV_USR_FS^^}${DEV_VAR_FS^^}" == *"BTRFS"* ]]; then
    cat >> /mnt/chrootinit.sh <<- EOM
echo "btrfs" >> /etc/initramfs-tools/modules
EOM
  fi;

  # Update initramfs & grub
  cat >> /mnt/chrootinit.sh <<- EOM
update-initramfs -k all -u
grub-mkconfig -o /boot/grub/grub.cfg
EOM
fi;

# Install btrbk/
if [[ ! -z "${DEV_BACKUP}" ]];  then
  cat >> /mnt/chrootinit.sh <<- EOM
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq btrbk
EOM

  cat >> /mnt/etc/cron.daily/btrbk <<- EOM
#!/bin/sh
exec /usr/sbin/btrbk -q run
EOM

  chown root:root /mnt/etc/cron.daily/btrbk
  chmod 755 /mnt/etc/cron.daily/btrbk
fi;

# Enable Systemd-Networkd
cat >> /mnt/chrootinit.sh <<- EOM
systemctl enable systemd-networkd
systemctl enable systemd-resolved
EOM

# Install sshd
if [[ "${TARGET_SYSTEM^^}" = "ARCH" ]]; then
  cat >> /mnt/chrootinit.sh <<- EOM
pacman -Sy --noconfirm openssh
sed -i 's/^#PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
EOM
fi;

if [[ "${TARGET_SYSTEM^^}" = "DEBIAN" ]]; then
  cat >> /mnt/chrootinit.sh <<- EOM
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openssh-server
sed -i 's/^#PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
EOM
fi;

# Call chrootinit.sh in chroot
chmod +x /mnt/chrootinit.sh
chroot /mnt /chrootinit.sh;

# Ansible Pull?
if [[ ! -z "${ANSIBLE_PULL_REPO}" ]]; then
  cat > /mnt/chrootinit.sh <<- EOM
#!/bin/bash
. /etc/profile

echo "deb http://ppa.launchpad.net/ansible/ansible/ubuntu trusty main" > /etc/apt/sources.list.d/ansible.list
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367
DEBIAN_FRONTEND=noninteractive apt-get update

DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git ansible

ansible-pull -U ${ANSIBLE_PULL_REPO} installer.yml
EOM

  # Run Pull
  chmod +x /mnt/chrootinit.sh
  chroot /mnt /chrootinit.sh;
fi;

# Fix systemd-resolvd
cat > /mnt/chrootinit.sh <<- EOM
#!/bin/bash
. /etc/profile
rm -f /etc/resolv.conf
ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
EOM
chmod +x /mnt/chrootinit.sh
chroot /mnt /chrootinit.sh;

# Cleanup
rm /mnt/chrootinit.sh
sync

if [[ "${AUTOREBOOT^^}" = "YES" ]]; then
  umount -R /mnt
  sync

  reboot now
fi;
