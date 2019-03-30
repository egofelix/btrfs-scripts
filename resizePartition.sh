#/bin/bash
echo $1
TARGET_DEVICE=`df -h $1 | tail -1 | cut -d' ' -f 1`
TARGET_CRYPTODEVICE=""

if [[ -z "${TARGET_DEVICE}" ]]; then
  echo "Cannot find device for $1"
  exit 1
fi;

if [[ "${TARGET_DEVICE}" == "/dev/mapper/crypt"* ]]; then
  echo "Crypted device!"
  TARGET_CRYPTODEVICE="${TARGET_DEVICE}"
  TARGET_DEVICE=`cryptsetup status ${TARGET_CRYPTODEVICE} | grep device | cut -d':' -f 2 | tr -d '[:space:]'`
fi;

TARGET_PARTITION_NUMBER=`echo ${TARGET_DEVICE} | sed 's/[^0-9]*//g'`
TARGET_DEVICE=`echo ${TARGET_DEVICE} | sed 's/[0-9]//'`
TARGET_DEVICE_NAME=`echo ${TARGET_DEVICE} | cut -c 6-`

NEXT_PART_NUMBER=`expr ${TARGET_PARTITION_NUMBER} + 1`
NEXT_PART="${TARGET_DEVICE}${NEXT_PART_NUMBER}"
if [[ -d "${NEXT_PART}" ]]; then
  echo "This Partition cannot be increased as is is not the last one on the drive!"
  exit 1
fi;

# Rescan drive
echo /sys/class/block/${TARGET_DEVICE_NAME}/device/rescan
echo 1>/sys/class/block/${TARGET_DEVICE_NAME}/device/rescan
partprobe

# Grow the Partition on the disk
echo growpart ${TARGET_DEVICE} ${TARGET_PARTITION_NUMBER}
growpart ${TARGET_DEVICE} ${TARGET_PARTITION_NUMBER}

if [[ ! -z "${TARGET_CRYPTODEVICE}" ]]; then
  # Rsize Cryptodevice
  echo cryptsetup resize ${TARGET_CRYPTODEVICE}
  cryptsetup resize ${TARGET_CRYPTODEVICE}
fi;

partprobe

# Detect FileSystem Type
if [[ ! -z "${TARGET_CRYPTODEVICE}" ]]; then
  TARGET_FSTYPE=`blkid -s TYPE ${TARGET_CRYPTODEVICE} | cut -d':' -f 2 | cut -d'=' -f 2 | sed 's/\"//g'`
else
  TARGET_FSTYPE=`blkid -s TYPE ${TARGET_DEVICE} | cut -d':' -f 2 | cut -d'=' -f 2 | sed 's/\"//g'`
fi;

echo $TARGET_FSTYPE
if [[ "${TARGET_FSTYPE^^}" == "BTRFS" ]]; then
  btrfs filesystem resize max $1
fi;

if [[ "${TARGET_FSTYPE^^}" == "EXT4" ]]; then
  if [[ ! -z "${TARGET_CRYPTODEVICE}" ]]; then
    resize2fs ${TARGET_CRYPTODEVICE}
  else
    resize2fs ${TARGET_DEVICE}
  fi;
fi;
