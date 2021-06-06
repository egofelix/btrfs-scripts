#!/bin/bash
function printHelp {
    echo "Usage: ${HOST_NAME} ${COMMAND_VALUE} [-c|--clean-disk] [-nc|--nocrypt] [-t|--target <harddisk>]";
}

function run {
    # Scan Arguments
    local CRYPT="true"; local NOCRYPT_FLAG="";
    local CLEAN_DISK="false"; local CLEAN_DISK_FLAG="";
    local HARDDISK="";
    local CRYPT_PASSWORD="test1234";
    local TARGETSNAPSHOT="";
    local VOLUME_PREFIX="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -t|--target) HARDDISK="$2"; shift ;;
            -c|--clean-disk) CLEAN_DISK="true"; CLEAN_DISK_FLAG=" --clean-disk";;
            -nc|--nocrypt) CRYPT="false"; NOCRYPT_FLAG=" --nocrypt";;
            -h|--help) printHelp; exit 0;;
            *) logError "Unknown argument $1"; printHelp; exit 1;;
        esac;
        shift;
    done;
    
    # Debug Variables
    logFunction "restore#arguments${CLEAN_DISK_FLAG}${NOCRYPT_FLAG} --target \`${HARDDISK}\`";
    
    # Include bootstrap includes
    local SCRIPT_SOURCE=$(readlink -f ${BASH_SOURCE});
    logDebug "Including ${SCRIPT_SOURCE%/*/*}/includes/bootstrap/*.sh";
    for f in ${SCRIPT_SOURCE%/*/*/*}/includes/bootstrap/*.sh; do source $f; done;
    
    # Validate HARDDISK
    if ! autodetect-harddisk --harddisk "${HARDDISK}"; then logError "Could not detect <harddisk>"; exit 1; fi;
    
    # Detect Server
    if ! autodetect-server; then
        logError "restore#Could not connect to remote server.";
        exit 1;
    fi;
    
    #Debug
    logFunction "restore#expandedArguments${NOCRYPT_FLAG} --target \`${HARDDISK}\`";
    
    # query volumes
    if ! runCmd ${SSH_CALL} "list-volumes"; then logError "SSH-Command \`$@\` failed: ${RUNCMD_CONTENT}."; exit 1; fi;
    local VOLUMES=${RUNCMD_CONTENT};
    
    # loop through volumes and list snapshots to check if which is the latest snapshot
    if [[ -z "${TARGETSNAPSHOT}" ]]; then
        if ! runCmd ${SSH_CALL} "detect-latest"; then logError "SSH-Command \`$@\` failed: ${RUNCMD_CONTENT}."; exit 1; fi;
        local TARGETSNAPSHOT=${RUNCMD_CONTENT};
    fi;
    
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
    logLine "Checking BTRFS-Subvolumes on SYSTEM-Partition...";
    if ! runCmd btrfs subvolume list /tmp/mnt/disks/system/@snapshots && ! runCmd btrfs subvolume create /tmp/mnt/disks/system/@snapshots; then logError "Failed to create btrfs @SNAPSHOTS-Volume"; exit 1; fi;
    if ! runCmd btrfs subvolume list /tmp/mnt/disks/system/@${VOLUME_PREFIX}swap && ! runCmd btrfs subvolume create /tmp/mnt/disks/system/@${VOLUME_PREFIX}swap; then logError "Failed to create btrfs @${VOLUME_PREFIX}swap-Volume"; exit 1; fi;
    if ! runCmd btrfs subvolume list /tmp/mnt/disks/system/@${VOLUME_PREFIX}var-logs-data && ! runCmd btrfs subvolume create /tmp/mnt/disks/system/@${VOLUME_PREFIX}var-logs-data; then logError "Failed to create btrfs @${VOLUME_PREFIX}var-logs-data-Volume"; exit 1; fi;
    if ! runCmd btrfs subvolume list /tmp/mnt/disks/system/@${VOLUME_PREFIX}var-tmp-data && ! runCmd btrfs subvolume create /tmp/mnt/disks/system/@${VOLUME_PREFIX}var-tmp-data; then logError "Failed to create btrfs @${VOLUME_PREFIX}var-tmp-data-Volume"; exit 1; fi;
    
    # Restore volumes
    for VOLUME in $(echo "${VOLUMES}" | sort)
    do
        logLine "Receiving snapshot for \"${VOLUME}\"...";
        if ! runCmd mkdir /tmp/mnt/disks/system/@snapshots/${VOLUME}; then logError "Failed to create snapshot directory for volume \"${VOLUME}\"."; exit 1; fi;
        
        logDebug ${SSH_CALL} "download-snapshot" "${VOLUME}" "${TARGETSNAPSHOT}";
        logDebug btrfs receive /tmp/mnt/disks/system/@snapshots/${VOLUME};
        
        # Receive Snapshot
        ${SSH_CALL} "download-snapshot" --volume "${VOLUME}" --snapshot "${TARGETSNAPSHOT}" | btrfs receive /tmp/mnt/disks/system/@snapshots/${VOLUME};
        if [[ $? -ne 0 ]]; then logError "Failed to receive the snapshot for volume \"${VOLUME}\"."; exit 1; fi;
        
        # Restore ROOTVOLUME
        RESTORERESULT=$(btrfs subvol snapshot /tmp/mnt/disks/system/@snapshots/${VOLUME}/${TARGETSNAPSHOT} /tmp/mnt/disks/system/${VOLUME} 2>&1);
        if [[ $? -ne 0 ]]; then logError "Failed to restore the snapshot for volume \"${VOLUME}\": ${RESTORERESULT}."; exit 1; fi;
    done;
    
    # Scan for fstab
    FSTABPATH="";
    logDebug "Searching for /etc/fstab...";
    for VOLUME in $(echo "${VOLUMES}" | sort)
    do
        logDebug "Searching in volume \"${VOLUME}\"...";
        
        if [[ -f "/tmp/mnt/disks/system/${VOLUME}/etc/fstab" ]]; then
            if [[ ! -z "${FSTABPATH}" ]]; then
                logError "Multiple fstab files found. Aborting.";
                exit 1;
            fi;
            
            FSTABPATH="/tmp/mnt/disks/system/${VOLUME}/etc/fstab";
        fi;
    done;
    if [[ -z "${FSTABPATH}" ]]; then logError "Could not locate /etc/fstab"; exit 1; fi;
    logDebug "FSTABPATH: ${FSTABPATH}";
    
    # Create @volumes
    ATVOLUMES=$(cat "${FSTABPATH}" | grep -o -P 'subvol=[\/]{0,1}@[^\s\,\)]*' | awk -F'=' '{print $2}');
    for VOLUME in $(echo "${ATVOLUMES}" | sort)
    do
        # Skip @snapshots as we have created it before restore
        if [[ "${VOLUME}" == "@snapshots" ]]; then continue; fi;
        
        # Fix for broken fstab (mount is there multiple times)
        if [[ -d "/tmp/mnt/disks/system/${VOLUME}" ]]; then continue; fi;
        
        logDebug "Creating ${VOLUME}...";
        CREATERESULT=$(btrfs subvol create /tmp/mnt/disks/system/${VOLUME} 2>&1);
        if [[ $? -ne 0 ]]; then logLine "Failed to create volume \"${VOLUME}\": ${CREATERESULT}."; exit 1; fi;
    done;
    
    
    # Mount
    if ! runCmd mkdir -p /tmp/mnt/root; then logError "Failed to create root mountpoint"; exit 1; fi;
    cat "${FSTABPATH}" | grep -v -P '^[\s]*#' | grep -v -P '^[\s]*$' | while read LINE; do
        logDebug "Handling fstab line: ${LINE}";
        LINEDEV=$(echo "$LINE" | awk '{print $1}');
        LINEMOUNT=$(echo "$LINE" | awk '{print $2}');
        LINEFS=$(echo "$LINE" | awk '{print $3}');
        LINESUBVOL=$(echo "$LINE" | awk '{print $4}' | grep -o -P 'subvol\=[^\s\,\)]*' | awk -F'=' '{print $2}');
        
        # Fix for broken fstab (mount is there multiple times, so we check if this is mounted already here)
        LINEDEVREGEX=$(echo "${LINEDEV}" | sed -e 's/[\.&]/\\&/g');
        LINEMOUNTREGEX=$(echo "/tmp/mnt/root${LINEMOUNT}" | sed -e 's/[\.&]/\\&/g');
        LINESUBVOLREGEX=$(echo "${LINESUBVOL}" | sed -e 's/[\.&]/\\&/g');
        MOUNTTEST=$(LANG=C mount | grep -P "${LINEDEVREGEX}[\s]+on[\s]+${LINEMOUNTREGEX}\s.*subvol\=[/]{0,1}${LINESUBVOLREGEX}");
        if ! isEmpty "${MOUNTTEST}"; then
            logDebug "Skipping line, as it is mounted already (Double check)";
            continue;
        fi;
        #end
        
        if [[ "${LINEDEV}" == "/dev/mapper/cryptsystem" ]] || [[ "${LINEDEV}" == "LABEL=system" ]]; then
            # Mount simple volume
            logDebug "Mounting ${LINESUBVOL} at ${LINEMOUNT}...";
            MOUNTRESULT=$(mount -o "subvol=${LINESUBVOL}" "${PART_SYSTEM}" "/tmp/mnt/root${LINEMOUNT}" 2>&1);
            if [[ $? -ne 0 ]]; then logLine "Failed to mount. Command \"mount -o \"subvol=${LINESUBVOL}\" \"${PART_SYSTEM}\" \"/tmp/mnt/root${LINEMOUNT}\"\", Result \"${MOUNTRESULT}\"."; exit 1; fi;
            elif [[ "${LINEMOUNT}" == "/boot" ]]; then
            # Mount boot partition
            MOUNTRESULT=$(mount ${PART_BOOT} "/tmp/mnt/root${LINEMOUNT}" 2>&1);
            if [[ $? -ne 0 ]]; then logLine "Failed to mount: ${MOUNTRESULT}."; exit 1; fi;
            elif [[ "${LINEMOUNT}" == "/boot/efi" ]]; then
            # Mount efi partition
            if ! runCmd mkdir /tmp/mnt/root${LINEMOUNT}; then logError "Failed to create efi directory."; exit 1; fi;
            MOUNTRESULT=$(mount ${PART_EFI} "/tmp/mnt/root${LINEMOUNT}" 2>&1);
            if [[ $? -ne 0 ]]; then logLine "Failed to mount: ${MOUNTRESULT}."; exit 1; fi;
            elif [[ "${LINEMOUNT,,}" == "none" ]] && [[ "${LINEFS,,}" == "swap" ]]; then
            # Create swapfile
            logDebug "Creating new swapfile...";
            if ! runCmd truncate -s 0 /tmp/mnt/root${LINEDEV}; then logError "Failed to truncate Swap-File at /tmp/mnt/root${LINEDEV}"; exit 1; fi;
            if ! runCmd chattr +C /tmp/mnt/root${LINEDEV}; then logError "Failed to chattr Swap-File at /tmp/mnt/root${LINEDEV}"; exit 1; fi;
            if ! runCmd chmod 600 /tmp/mnt/root${LINEDEV}; then logError "Failed to chmod Swap-File at /tmp/mnt/root${LINEDEV}"; exit 1; fi;
            if ! runCmd btrfs property set /tmp/mnt/root${LINEDEV} compression none; then logError "Failed to disable compression for Swap-File at /tmp/mnt/root${LINEDEV}"; exit 1; fi;
            if ! runCmd fallocate /tmp/mnt/root${LINEDEV} -l2g; then logError "Failed to fallocate 2G Swap-File at /tmp/mnt/root${LINEDEV}"; exit 1; fi;
            if ! runCmd mkswap /tmp/mnt/root${LINEDEV}; then logError "Failed to mkswap for Swap-File at /tmp/mnt/root${LINEDEV}"; exit 1; fi;
        else
            # unknown, we skip it here
            logWarn "Skipping unknown mount ${LINEMOUNT}.";
        fi;
    done;
}

run $@;
exit 0;