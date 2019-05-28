#!/bin/bash

# Parse arguments
CRYPTED=""
TARGET_SYSTEM="debian"

DEV_ROOT="/dev/sda"
DEV_ROOT_FS="ext4"

DEV_ETC=""
DEV_ETC_FS="ext4"

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

FILESYS="btrfs"
VERBOSE=""
TARGET_HOSTNAME=""

ANSIBLE_PULL_REPO=""

while [ "$#" -gt 0 ]; do
  case "$1" in
      --verbose) export VERBOSE=" --verbose"; shift 1;;
      --system) export TARGET_SYSTEM="$2"; shift 2;;

      --root) export DEV_ROOT="$2"; shift 2;;
      --root-fs) export DEV_ROOT_FS="$2"; shift 2;;

      --etc) export DEV_ETC="$2"; shift 2;;
      --etc-fs) export DEV_ETC_FS="$2"; shift 2;;

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

      --crypt) export CRYPTED="true"; shift 1;;
      --hostname) export TARGET_HOSTNAME="$2"; shift 2;;

      --pullrepo) export ANSIBLE_PULL_REPO="$2"; shift 2;;

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
    if [[ ! -z "${5}" ]]; then
      cryptsetup --batch-mode luksFormat --type luks1 ${1} -d ${5}
      cryptsetup --batch-mode open ${1} crypt${2} -d ${5}
    else
      echo test1234 | cryptsetup --batch-mode luksFormat --type luks1 ${1}
      echo test1234 | cryptsetup --batch-mode open ${1} crypt${2}
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
    btrfs subvol set-default `btrfs subvol list /tmp/btrfs/${2} | grep data | cut -d' ' -f2` /tmp/btrfs/${2}
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
    formatPartition ${1}1 ${2} ${3} ${4} /mnt/crypt.key
  else
    formatPartition ${1}1 ${2} ${3} ${4}
  fi;

  # Mount
  mkdir /mnt/${2}
  if [[ "${4^^}" = "TRUE" ]]; then
    mount /dev/mapper/crypt${2} /mnt/${2}
  else
    mount ${1}1 /mnt/${2}
  fi;

  sync
}

if [[ ! -d "/sys/firmware/efi" ]]; then
  echo "BIOS IS NOT SUPPORTED"
  exit 1
fi;

if [[ "${TARGET_SYSTEM^^}" != "DEBIAN" ]]; then
  echo "Only supported target system is debian atm"
  exit 1
fi;

if [[ -z "${TARGET_HOSTNAME}" ]]; then
  echo "Please specify a hostname with --hostname HOSTNAME"
  exit 1
fi;

installPackage debootstrap "" debootstrap;
installPackage parted "" parted;

# Format Disk
sfdisk ${DEV_ROOT} <<- EOM
label: gpt
unit: sectors

start=        2048, size=      204800, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="efi"
start=      206848, size=      512000, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="boot"
start=      718848, size=      204800, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="root"
EOM
sync

# Resize Root Partition
parted ${DEV_ROOT} resizepart 3 100%
sync

# Create Filesystems
mkfs.vfat -F32 ${DEV_ROOT}1
fatlabel ${DEV_ROOT} EFI
mkfs.ext2 -F -L boot ${DEV_ROOT}2
formatPartition ${DEV_ROOT}3 root ${DEV_ROOT_FS} ${CRYPTED}
sync

# Mount Root
if [[ "${CRYPTED^^}" = "TRUE" ]]; then
  mount /dev/mapper/cryptroot /mnt
else
  mount ${DEV_ROOT}3 /mnt
fi;

# Mount Boot and Efi
mkdir /mnt/boot
mount ${DEV_ROOT}2 /mnt/boot
mkdir /mnt/boot/efi
mount ${DEV_ROOT}1 /mnt/boot/efi
sync

# Generate a key file
if [[ "${CRYPTED^^}" = "TRUE" ]]; then
  dd if=/dev/urandom of=/mnt/crypt.key bs=1024 count=1
  echo test1234 | cryptsetup --batch-mode luksAddKey ${DEV_ROOT}3 /mnt/crypt.key
fi;

# Format Additional Partitions?
if [[ ! -z "${DEV_ETC}" ]];  then formatDrive ${DEV_ETC} etc ${DEV_ETC_FS} ${CRYPTED}; fi;
if [[ ! -z "${DEV_HOME}" ]]; then formatDrive ${DEV_HOME} home ${DEV_HOME_FS} ${CRYPTED}; fi;
if [[ ! -z "${DEV_OPT}" ]];  then formatDrive ${DEV_OPT} opt ${DEV_OPT_FS} ${CRYPTED}; fi;
if [[ ! -z "${DEV_SRV}" ]];  then formatDrive ${DEV_SRV} srv ${DEV_SRV_FS} ${CRYPTED}; fi;
if [[ ! -z "${DEV_USR}" ]];  then formatDrive ${DEV_USR} usr ${DEV_USR_FS} ${CRYPTED}; fi;
if [[ ! -z "${DEV_VAR}" ]];  then formatDrive ${DEV_VAR} var ${DEV_VAR_FS} ${CRYPTED}; fi;

# Install Base to /mnt
echo "Installing Base System..."

# Install Strap
if [[ "${TARGET_SYSTEM^^}" = "DEBIAN" ]]; then
  debootstrap stretch /mnt http://ftp.de.debian.org/debian/;
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
mkdir /mnt/tmp
mount -t tmpfs tmpfs /mnt/tmp

# Generate fstab
genfstab -pL /mnt >> /mnt/etc/fstab

# Setup Network
# Disable old interfaces
rm -f /mnt/etc/network/interfaces
rm -f /mnt/etc/network/interfaces.d/*

# Enable Systemd-Networkd resolv.conf
rm -f /mnt/etc/resolv.conf
ln -s /run/systemd/resolve/resolv.conf /mnt/etc/resolv.conf

# Setup Systemd-Networkd interface
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
cat >> /mnt/chrootinit.sh <<- EOM
DEBIAN_FRONTEND=noninteractive apt-get update -qq
EOM

# Install Locales
cat >> /mnt/chrootinit.sh <<- EOM
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq locales console-data dirmngr
sed -i '/de_DE.UTF-8/s/^#//' /etc/locale.gen
sed -i '/en_US.UTF-8/s/^#//' /etc/locale.gen
locale-gen
echo -e 'LANG="en_US.UTF-8"\nLANGUAGE="en_US.UTF-8"\nLC_ALL="en_US.UTF-8"\n' > /etc/default/locale
EOM

# Set Root Password
cat >> /mnt/chrootinit.sh <<- EOM
echo -e "root\nroot" | passwd root
EOM

# Install linux-image
cat >> /mnt/chrootinit.sh <<- EOM
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq linux-image-amd64
EOM

if [[ "${DEV_ROOT_FS^^}${DEV_ETC_FS^^}${DEV_HOME_FS^^}${DEV_OPT_FS^^}${DEV_SRV_FS^^}${DEV_USR_FS^^}${DEV_VAR_FS^^}" == *"BTRFS"* ]]; then
cat >> /mnt/chrootinit.sh <<- EOM
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq btrfs-progs
EOM
fi;

# Install Bootloader
cat >> /mnt/chrootinit.sh <<- EOM
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq grub2-common grub-efi
grub-install
grub-mkconfig -o /boot/grub/grub.cfg
EOM

if [[ "${CRYPTED^^}" = "TRUE" ]]; then
  # Install cryptsetup and dropbear
  cat >> /mnt/chrootinit.sh <<- EOM
chown root:root /crypt.key
chmod 600 /crypt.key
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq cryptsetup #dropbear-initramfs
echo cryptroot /dev/sda3 none luks,allow-discards > /etc/crypttab
EOM

  # Additional Drives?
  if [[ ! -z "${DEV_ETC}" ]];  then echo "echo cryptetc ${DEV_ETC}1 /crypt.key luks,allow-discards >> /etc/crypttab" >> /mnt/chrootinit.sh; fi;
  if [[ ! -z "${DEV_HOME}" ]];  then echo "echo crypthome ${DEV_HOME}1 /crypt.key luks,allow-discards >> /etc/crypttab" >> /mnt/chrootinit.sh; fi;
  if [[ ! -z "${DEV_OPT}" ]];  then echo "echo cryptopt ${DEV_OPT}1 /crypt.key luks,allow-discards >> /etc/crypttab" >> /mnt/chrootinit.sh; fi;
  if [[ ! -z "${DEV_SRV}" ]];  then echo "echo cryptsrv ${DEV_SRV}1 /crypt.key luks,allow-discards >> /etc/crypttab" >> /mnt/chrootinit.sh; fi;
  if [[ ! -z "${DEV_USR}" ]];  then echo "echo cryptusr ${DEV_USR}1 /crypt.key luks,allow-discards >> /etc/crypttab" >> /mnt/chrootinit.sh; fi;
  if [[ ! -z "${DEV_VAR}" ]];  then echo "echo cryptvar ${DEV_VAR}1 /crypt.key luks,allow-discards >> /etc/crypttab" >> /mnt/chrootinit.sh; fi;

  # Setup btrfs module for initramfs
  if [[ "${DEV_ROOT_FS^^}${DEV_ETC_FS^^}${DEV_HOME_FS^^}${DEV_OPT_FS^^}${DEV_SRV_FS^^}${DEV_USR_FS^^}${DEV_VAR_FS^^}" == *"BTRFS"* ]]; then
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

# Enable Systemd-Networkd
cat >> /mnt/chrootinit.sh <<- EOM
systemctl enable systemd-networkd
EOM

# Install sshd
cat >> /mnt/chrootinit.sh <<- EOM
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openssh-server
sed -i 's/^#PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
EOM

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
  chroot /mnt /chrootinit.sh;
fi;

# Cleanup
rm /mnt/chrootinit.sh
sync

umount -R /mnt
reboot now
