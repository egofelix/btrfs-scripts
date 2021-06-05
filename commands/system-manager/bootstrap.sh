#!/bin/bash
function printHelp {
    echo "Usage: ${HOST_NAME} ${COMMAND_VALUE} [-nc|--nocrypt] [-t|--target <harddisk>] [-d|--distro <volume>]";
}

function run {
    # Scan Arguments
    local CRYPT="true"; local NOCRYPT_FLAG="";
    local HARDDISK="";
    local DISTRO="archlinux";
    local CRYPT_PASSWORD="test1234";
    local SUBVOLUMES="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -t|--target) HARDDISK="$2"; shift ;;
            -d|--distro) DISTRO="$2"; shift ;;
            -nc|--nocrypt) CRYPT="false"; NOCRYPT_FLAG=" --nocrypt";;
            -h|--help) printHelp; exit 0;;
            *) logError "Unknown argument $1"; printHelp; exit 1;;
        esac;
        shift;
    done;
    
    # Debug Variables
    logFunction "bootstrap#arguments${NOCRYPT_FLAG} --target \`${HARDDISK}\` --distro \`${DISTRO}\`";
    
    # Include bootstrap includes
    local SCRIPT_SOURCE=$(readlink -f ${BASH_SOURCE});
    logDebug "Including ${SCRIPT_SOURCE%/*/*}/includes/bootstrap/*.sh";
    for f in ${SCRIPT_SOURCE%/*/*/*}/includes/bootstrap/*.sh; do source $f; done;
    
    # Defaults
    if [[ -z "${SUBVOLUMES}" ]]; then SUBVOLUMES="home var srv usr opt"; fi;
    
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
    
    # Get user confirmation
    logDebug "Checking if we need to format";
    if ! harddisk-format-check --crypt "${CRYPT}" --crypt-mapper "cryptsystem" --harddisk "${HARDDISK}"; then
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
    logLine "Checking BTRFS-Subvolumes on SYSTEM-Partition...";
    if ! runCmd btrfs subvolume list /tmp/mnt/disks/system/@snapshots && ! runCmd btrfs subvolume create /tmp/mnt/disks/system/@snapshots; then logError "Failed to create btrfs @SNAPSHOTS-Volume"; exit 1; fi;
    if ! runCmd btrfs subvolume list /tmp/mnt/disks/system/@swap && ! runCmd btrfs subvolume create /tmp/mnt/disks/system/@swap; then logError "Failed to create btrfs @SWAP-Volume"; exit 1; fi;
    if ! runCmd btrfs subvolume list /tmp/mnt/disks/system/@logs && ! runCmd btrfs subvolume create /tmp/mnt/disks/system/@logs; then logError "Failed to create btrfs @LOGS-Volume"; exit 1; fi;
    if ! runCmd btrfs subvolume list /tmp/mnt/disks/system/@tmp && ! runCmd btrfs subvolume create /tmp/mnt/disks/system/@tmp; then logError "Failed to create btrfs @TMP-Volume"; exit 1; fi;
    if ! runCmd btrfs subvolume list /tmp/mnt/disks/system/${DISTRO,,}-root-data && ! runCmd btrfs subvolume create /tmp/mnt/disks/system/${DISTRO,,}-root-data; then logError "Failed to create btrfs ROOT-DATA-Volume"; exit 1; fi;
    for subvolName in ${SUBVOLUMES}
    do
        if ! runCmd btrfs subvolume list /tmp/mnt/disks/system/${DISTRO,,}-${subvolName,,}-data && ! runCmd btrfs subvolume create /tmp/mnt/disks/system/${DISTRO,,}-${subvolName,,}-data; then logError "Failed to create btrfs ${subvolName^^}-DATA-Volume"; exit 1; fi;
    done;
    
    # Mount Subvolumes
    logLine "Mounting...";
    mkdir -p /tmp/mnt/root;
    
    if runCmd findmnt -r -n /tmp/mnt/root; then
        logDebug "Checking mount on /tmp/mnt/root";
        local MOUNTTEST=$(echo "${RUNCMD_CONTENT}" | grep "${PART_SYSTEM}\[/${DISTRO,,}-${subvolName,,}-data\]");
        echo "MOUNTTEST: ${MOUNTTEST}";
        echo "MOUNTTEST: ${RUNCMD_CONTENT}";
        
        exit 1;
        elif ! runCmd mount -o subvol=/${DISTRO,,}-root-data ${PART_SYSTEM} /tmp/mnt/root; then
        logError "Failed to Mount Subvolume ${DISTRO^^}-ROOT-DATA at /tmp/mnt/root";
        exit 1;
    fi;
    
    mkdir -p /tmp/mnt/root/boot;
    if ! runCmd mount ${PART_BOOT} /tmp/mnt/root/boot; then logError "Failed to mount BOOT-Partition"; exit 1; fi;
    if ! runCmd mkdir -p /tmp/mnt/root/boot/efi; then logError "Failed to create efi directory at /tmp/mnt/root/boot/efi"; exit 1; fi;
    if ! runCmd mount ${PART_EFI} /tmp/mnt/root/boot/efi; then logError "Failed to mount EFI-Partition"; exit 1; fi;
    
    
    echo "Todo";
    printHelp;
    exit 1;
}

run $@;
exit 0;