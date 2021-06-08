#!/bin/bash
function printHelp {
    echo "Usage: ${HOST_NAME} ${COMMAND_VALUE} [-c|--clean-disk] [-nc|--nocrypt] [-t|--target <harddisk>] [-d|--distro <distro>]";
    echo "";
    echo "    ${HOST_NAME} ${COMMAND_VALUE} --distro debian";
    echo "      Will install debian to first harddisk";
    echo "";
    echo "    ${HOST_NAME} ${COMMAND_VALUE} --distro archlinux --target /dev/sdb";
    echo "      Will install archlinux to /dev/sdb";
    echo "";
    echo "If you omit the <harddisk> then the script will try to locate the first harddisk automatically.";
    echo "";
}

function run {
    # Scan Arguments
    local CRYPT="true"; local NOCRYPT_FLAG="";
    local CLEAN_DISK="false"; local CLEAN_DISK_FLAG="";
    local HARDDISK="";
    local DISTRO="archlinux";
    local CRYPT_PASSWORD="test1234";
    local SUBVOLUMES="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -t|--target) HARDDISK="$2"; shift ;;
            -d|--distro) DISTRO="$2"; shift ;;
            -c|--clean-disk) CLEAN_DISK="true"; CLEAN_DISK_FLAG=" --clean-disk";;
            --use-subvolume) SUBVOLUMES="${SUBVOLUMES} ${2}"; shift ;;
            -nc|--nocrypt) CRYPT="false"; NOCRYPT_FLAG=" --nocrypt";;
            -h|--help) printHelp; exit 0;;
            *) logError "Unknown argument $1"; printHelp; exit 1;;
        esac;
        shift;
    done;
    
    # Debug Variables
    logFunction "bootstrap#arguments${CLEAN_DISK_FLAG}${NOCRYPT_FLAG} --target \`${HARDDISK}\` --distro \`${DISTRO}\`";
    
    # Include bootstrap includes
    local SCRIPT_SOURCE=$(readlink -f ${BASH_SOURCE});
    logDebug "Including ${SCRIPT_SOURCE%/*/*}/includes/bootstrap/*.sh";
    for f in ${SCRIPT_SOURCE%/*/*/*}/includes/bootstrap/*.sh; do source $f; done;
    
    # Defaults
    if [[ -z "${SUBVOLUMES}" ]]; then SUBVOLUMES="home srv"; fi;
    
    # Validate HARDDISK
    if ! autodetect-harddisk --harddisk "${HARDDISK}"; then logError "Could not detect <harddisk>"; exit 1; fi;
    
    #Debug
    logFunction "bootstrap#expandedArguments${NOCRYPT_FLAG} --target \`${HARDDISK}\` --distro \`${DISTRO}\` --subvolumes \`${SUBVOLUMES}\`";
    
    # Test if we are running a live iso
    local IS_LIVE="false";
    if ! runCmd findmnt -n / -r; then logError "Could not detect rootfs type"; exit 1; fi;
    local ROOTFS_TYPE=$(echo "${RUNCMD_CONTENT,,}" | cut -d' ' -f 2);
    case "${ROOTFS_TYPE,,}" in
        airootfs) IS_LIVE="true";;
        *) IS_LIVE="false";;
    esac;
    
    # Warn user if we didnt detected a live system
    if ! isTrue ${IS_LIVE}; then
        read -p "You are not running a live system, bootstrap to a running system will fail, continue? [yN]: " -n 1 -r
        echo    # (optional) move to a new line
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            logError "Script canceled by user";
            exit 1;
        fi
    fi;
    
    # Detect current system & Check Dependencies and Install them if live system, otherwise error out
    if isTrue ${IS_LIVE}; then
        logDebug "Checking Dependencies...";
        source "${BASH_SOURCE%/*/*/*}/scripts/dependencies.sh";
    fi;
    
    # Unmount old
    $(umount -R /tmp/mnt/root || true);
    $(umount -R /tmp/mnt/disks/system || true);
    
    # Format the harddisk
    logDebug "Checking if we need to format";
    if isTrue "${CLEAN_DISK}" || ! harddisk-format-check --crypt "${CRYPT}" --crypt-mapper "cryptsystem" --harddisk "${HARDDISK}"; then
        # Get user confirmation
        read -p "You are now deleting all contents of \"${HARDDISK}\", continue? [yN]: " -n 1 -r
        echo    # (optional) move to a new line
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            logError "Script canceled by user";
            exit 1;
        fi;
        
        # Format Drive
        if ! harddisk-format --crypt "${CRYPT}" --crypt-mapper "cryptsystem" --crypt-password "${CRYPT_PASSWORD}" --harddisk "${HARDDISK}"; then
            logError "Failed to format ${HARDDISK}";
            exit 1;
        fi;
    fi;
    
    # Setup variables
    local PART_EFI="${HARDDISK}2"
    local PART_BOOT="${HARDDISK}3"
    local PART_SYSTEM="${HARDDISK}4"
    if isTrue "${CRYPT}"; then PART_SYSTEM="/dev/mapper/cryptsystem"; fi;
    
    # Mount system
    logLine "Mounting SYSTEM-Partition at /tmp/mnt/disks/system"
    mkdir -p /tmp/mnt/disks/system
    
    if runCmd findmnt -n -r /tmp/mnt/disks/system; then
        local CURRENTLYMOUNTED=$(echo "${RUNCMD_CONTENT}" | cut -d' ' -f 2);
        
        if [[ "${CURRENTLYMOUNTED}" != "${PART_SYSTEM}" ]]; then
            logError "There seems to be another drive mounted at /tmp/mnt/disks/system";
            exit 1;
        fi;
    elif ! runCmd mount ${PART_SYSTEM} /tmp/mnt/disks/system; then logError "Failed to mount SYSTEM-Partition"; exit 1; fi;
    
    # Create Subvolumes
    local VOLUME_PREFIX="${DISTRO,,}-";
    VOLUME_PREFIX="";
    logLine "Checking BTRFS-Subvolumes on SYSTEM-Partition...";
    if ! runCmd btrfs subvolume list /tmp/mnt/disks/system/@snapshots && ! runCmd btrfs subvolume create /tmp/mnt/disks/system/@snapshots; then logError "Failed to create btrfs @SNAPSHOTS-Volume"; exit 1; fi;
    if ! runCmd btrfs subvolume list /tmp/mnt/disks/system/@${VOLUME_PREFIX}swap && ! runCmd btrfs subvolume create /tmp/mnt/disks/system/@${VOLUME_PREFIX}swap; then logError "Failed to create btrfs @${VOLUME_PREFIX}swap-Volume"; exit 1; fi;
    if ! runCmd btrfs subvolume list /tmp/mnt/disks/system/@${VOLUME_PREFIX}var-logs-data && ! runCmd btrfs subvolume create /tmp/mnt/disks/system/@${VOLUME_PREFIX}var-logs-data; then logError "Failed to create btrfs @${VOLUME_PREFIX}var-logs-data-Volume"; exit 1; fi;
    if ! runCmd btrfs subvolume list /tmp/mnt/disks/system/@${VOLUME_PREFIX}var-tmp-data && ! runCmd btrfs subvolume create /tmp/mnt/disks/system/@${VOLUME_PREFIX}var-tmp-data; then logError "Failed to create btrfs @${VOLUME_PREFIX}var-tmp-data-Volume"; exit 1; fi;
    if ! runCmd btrfs subvolume list /tmp/mnt/disks/system/${VOLUME_PREFIX}root-data && ! runCmd btrfs subvolume create /tmp/mnt/disks/system/${VOLUME_PREFIX}root-data; then logError "Failed to create btrfs ${VOLUME_PREFIX}ROOT-DATA-Volume"; exit 1; fi;
    for subvolName in ${SUBVOLUMES}
    do
        if ! runCmd btrfs subvolume list /tmp/mnt/disks/system/${VOLUME_PREFIX}${subvolName,,}-data && ! runCmd btrfs subvolume create /tmp/mnt/disks/system/${VOLUME_PREFIX}${subvolName,,}-data; then logError "Failed to create btrfs ${VOLUME_PREFIX}${subvolName^^}-DATA-Volume"; exit 1; fi;
    done;
    
    # Mount Subvolumes
    logLine "Mounting...";
    function mountItem() {
        mkdir -p ${1};
        
        if runCmd findmnt -r -n ${1};
        then
            logDebug "Checking mount on ${1}";
            
            if [[ -z "${3:-}" ]]; then
                local MOUNTTEST=$(echo "${RUNCMD_CONTENT}" | cut -d' ' -f 2 | grep "${2}");
            else
                local MOUNTTEST=$(echo "${RUNCMD_CONTENT}" | cut -d' ' -f 2 | grep "${2}\[/${3}\]");
            fi;
            
            if [[ -z "${MOUNTTEST}" ]]; then
                logError "There seems to be another mount at ${1}";
                return 1;
            fi;
        elif ! isEmpty "${3:-}" && ! runCmd mount -o subvol=/${3} ${2} ${1};
        then
            logError "Failed to Mount Subvolume ${3} at ${1}";
            return 1;
        elif isEmpty "${3:-}" && ! runCmd mount ${2} ${1};
        then
            logError "Failed to Mount ${2} at ${1}";
            return 1;
        fi;
        
        return 0;
    }
    
    if ! mountItem /tmp/mnt/root "${PART_SYSTEM}" "${VOLUME_PREFIX}root-data"; then logError "Failed to mount ${VOLUME_PREFIX}ROOT-Volume"; exit 1; fi;
    if ! mountItem /tmp/mnt/root/boot "${PART_BOOT}"; then logError "Failed to mount BOOT-Partition"; exit 1; fi;
    if ! mountItem /tmp/mnt/root/boot/efi "${PART_EFI}"; then logError "Failed to mount EFI-Partition"; exit 1; fi;
    if ! mountItem /tmp/mnt/root/.snapshots "${PART_SYSTEM}" "@snapshots"; then logError "Failed to Mount Snapshot-Volume at /tmp/mnt/root/.snapshots"; exit 1; fi;
    
    # Mount Swap-Volume
    if ! mountItem /tmp/mnt/root/.swap "${PART_SYSTEM}" "@${VOLUME_PREFIX}swap"; then logError "Failed to Mount ${VOLUME_PREFIX}swap-Volume at /tmp/mnt/root/.swap"; exit 1; fi;
    
    # Create SwapFile
    if [[ ! -f /tmp/mnt/root/.swap/swapfile ]]; then
        if ! runCmd truncate -s 0 /tmp/mnt/root/.swap/swapfile; then logError "Failed to truncate Swap-File at /tmp/mnt/root/.swap/swapfile"; exit 1; fi;
        if ! runCmd chattr +C /tmp/mnt/root/.swap/swapfile; then logError "Failed to chattr Swap-File at /tmp/mnt/root/.swap/swapfile"; exit 1; fi;
        if ! runCmd chmod 600 /tmp/mnt/root/.swap/swapfile; then logError "Failed to chmod Swap-File at /tmp/mnt/root/.swap/swapfile"; exit 1; fi;
        if ! runCmd btrfs property set /tmp/mnt/root/.swap/swapfile compression none; then logError "Failed to disable compression for Swap-File at /tmp/mnt/root/.swap/swapfile"; exit 1; fi;
        if ! runCmd fallocate -l 2G /tmp/mnt/root/.swap/swapfile; then logError "Failed to fallocate 2G Swap-File at /tmp/mnt/root/.swap/swapfile"; exit 1; fi;
        if ! runCmd mkswap /tmp/mnt/root/.swap/swapfile; then logError "Failed to mkswap for Swap-File at /tmp/mnt/root/.swap/swapfile"; exit 1; fi;
    fi;
    
    # Mount Subvolumes
    for subvolName in ${SUBVOLUMES}
    do
        if ! mountItem /tmp/mnt/root/${subvolName,,} "${PART_SYSTEM}" "${VOLUME_PREFIX}${subvolName,,}-data"; then logError "Failed to Mount ${VOLUME_PREFIX}${subvolName,,}-data-Volume at /tmp/mnt/root/${subvolName,,}"; exit 1; fi;
    done;
    
    # Create mounts for /var/logs and /var/tmp if /var is on a seperate partition
    if [[ ! -z $(LANG=C mount | grep ' /tmp/mnt/root/var type ') ]]; then
        if ! mountItem /tmp/mnt/root/var/logs "${PART_SYSTEM}" "@${VOLUME_PREFIX}var-logs-data"; then logError "Failed to Mount @${VOLUME_PREFIX}var-logs-data-Volume at /tmp/mnt/root/var/logs"; exit 1; fi;
        if ! mountItem /tmp/mnt/root/var/tmp "${PART_SYSTEM}" "@${VOLUME_PREFIX}var-tmp-data"; then logError "Failed to Mount @${VOLUME_PREFIX}var-tmp-data-Volume at /tmp/mnt/root/var/tmp"; exit 1; fi;
    fi;
    
    # Install base system
    if [[ -d /tmp/mnt/root/etc ]]; then
        logLine "Skipping strap, there seems to be a system already";
    else
        logLine "Installing Base-System (${DISTRO^^})...";
        source "${BASH_SOURCE%/*/*/*}/scripts/strap.sh";
    fi;
    
    # Generate fstab
    genfstab -pL /tmp/mnt/root >> /tmp/mnt/root/etc/fstab;
    if [ $? -ne 0 ]; then
        logError "Failed to generate fstab";
        exit 1;
    fi;
    
    if isTrue "${CRYPT}"; then
        if ! runCmd sed -i 's#^LABEL=system#/dev/mapper/cryptsystem#g' /tmp/mnt/root/etc/fstab; then logError "Failed to modify fstab"; exit 1; fi;
    fi;
    
    if ! runCmd sed -i 's/,subvolid=[0-9]*//g' /tmp/mnt/root/etc/fstab; then logError "Failed to modify fstab"; exit 1; fi;
    
    # Check if there are more subvol defined and remove ones starting with / if so
    if runCmd grep -E '\,subvol=[^\/][A-Za-z]+' /etc/fstab; then
        if ! runCmd sed -i 's/,subvol=\/[^,]*//g' /tmp/mnt/root/etc/fstab; then logError "Failed to modify fstab"; exit 1; fi;
    fi;
    
    # Add Swapfile to fstab
    echo '# Swapfile' >> /tmp/mnt/root/etc/fstab;
    echo '/.swap/swapfile                 none                            swap    sw                                                      0 0' >> /tmp/mnt/root/etc/fstab;
    
    # Install CryptoKey
    if isTrue "${CRYPT}"; then
        if ! runCmd cp /tmp/crypto.key /tmp/mnt/root/etc/; then logError "Failed to copy crypto.key"; exit 1; fi;
        if ! runCmd cp /tmp/crypto.header /tmp/mnt/root/etc/; then logError "Failed to copy crypto.header"; exit 1; fi;
    fi;
    
    # Prepare ChRoot
    source "${BASH_SOURCE%/*/*/*}/scripts/chroot_prepare.sh";
    
    # Run installer
    logLine "Setting up system...";
    source "${BASH_SOURCE%/*/*/*}/scripts/chroot.sh";
    
    # Question for CHROOT
    sync;
    read -p "Your system has been installed. Do you want to chroot into the system now and make changes? [yN]: " -n 1 -r;
    echo    # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        logLine "Entering chroot...";
        chroot /tmp/mnt/root /bin/bash;
        sync;
    fi
    
    # Restore resolve
    logDebug "Restoring resolv.conf...";
    source "${BASH_SOURCE%/*/*/*}/scripts/restoreresolv.sh";
    
    # Question for reboot
    read -p "Do you want to reboot into the system now? [Yn]: " -n 1 -r;
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ $REPLY =~ ^$ ]]; then
        sync;
        source "${BASH_SOURCE%/*/*/*}/scripts/unmount.sh";
        logLine "Rebooting...";
        reboot now;
        exit 0;
    fi
    
    # Finish
    sync;
    logLine "Your system is ready! Type reboot to boot it.";
}

run $@;
exit 0;