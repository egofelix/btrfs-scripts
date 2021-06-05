#!/bin/bash

function harddisk-format-check {
    # Scan Arguments
    local ARG_HARDDISK="";
    local ARG_CRYPT="false";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --crypt) ARG_CRYPT="$2"; shift;;
            --harddisk) ARG_HARDDISK="$2"; shift;;
            *) logError "harddisk-format-check#Unknown Argument: $1"; return 1;;
        esac;
        shift;
    done;
    
    # Autodetect ${HARDDISK}
    if ! autodetect-harddisk --harddisk "${ARG_HARDDISK}"; then logError "Could not format harddisk. No Harddisk specified"; return 1; fi;
    
        # Check if we need partitioning?
    local NEEDS_PARTITIONING="false";

    # Check that we dont have /dev/sda5
    if ! isTrue ${NEEDS_PARTITIONING} && runCmd blkid "${HARDDISK}5"; then NEEDS_PARTITIONING="true"; fi;
    
    # Check if /dev/sda is gpt type
    if ! isTrue ${NEEDS_PARTITIONING} && ! runCmd blkid "${HARDDISK}"; then NEEDS_PARTITIONING="true"; fi;
    if [[ -z $(echo "${RUNCMD_CONTENT}" | grep "PTTYPE=\"gpt\"") ]]; then NEEDS_PARTITIONING="true"; fi;

    # Check if /dev/sda1 is type ext2 and labeled BOOT
    if ! isTrue ${NEEDS_PARTITIONING} && ! runCmd blkid "${HARDDISK}1"; then NEEDS_PARTITIONING="true"; fi;
    if [[ -z $(echo "${RUNCMD_CONTENT}" | grep "TYPE=\"ext2\"") ]]; then NEEDS_PARTITIONING="true"; fi;
    if [[ -z $(echo "${RUNCMD_CONTENT}" | grep "LABEL=\"boot\"") ]]; then NEEDS_PARTITIONING="true"; fi;

    # Check if /dev/sda2 is type vfat
    if ! isTrue ${NEEDS_PARTITIONING} && ! runCmd blkid "${HARDDISK}2"; then NEEDS_PARTITIONING="true"; fi;
    if [[ -z $(echo "${RUNCMD_CONTENT}" | grep "TYPE=\"vfat\"") ]]; then NEEDS_PARTITIONING="true"; fi;

    # Check if /dev/sda3 is type ext2 and labeled BOOT and has PARTLABEL=boot
    if ! isTrue ${NEEDS_PARTITIONING} && ! runCmd blkid "${HARDDISK}3"; then NEEDS_PARTITIONING="true"; fi;
    if [[ -z $(echo "${RUNCMD_CONTENT}" | grep "TYPE=\"ext2\"") ]]; then NEEDS_PARTITIONING="true"; fi;
    if [[ -z $(echo "${RUNCMD_CONTENT}" | grep "LABEL=\"boot\"") ]]; then NEEDS_PARTITIONING="true"; fi;
    if [[ -z $(echo "${RUNCMD_CONTENT}" | grep "PARTLABEL=\"boot\"") ]]; then NEEDS_PARTITIONING="true"; fi;
    
    # Check if /dev/sda4 is type crypto_LUKS and and has PARTLABEL=system
    if ! isTrue ${NEEDS_PARTITIONING} && ! runCmd blkid "${HARDDISK}4"; then NEEDS_PARTITIONING="true"; fi;
    if [[ -z $(echo "${RUNCMD_CONTENT}" | grep "LABEL=\"system\"") ]]; then NEEDS_PARTITIONING="true"; fi;
    if isTrue ${ARG_CRYPT}; then
        if [[ -z $(echo "${RUNCMD_CONTENT}" | grep "TYPE=\"crypto_LUKS\"") ]]; then NEEDS_PARTITIONING="true"; fi;
    else
        if [[ -z $(echo "${RUNCMD_CONTENT}" | grep "TYPE=\"btrfs\"") ]]; then NEEDS_PARTITIONING="true"; fi;
    fi;    
    if [[ -z $(echo "${RUNCMD_CONTENT}" | grep "PARTLABEL=\"system\"") ]]; then NEEDS_PARTITIONING="true"; fi;

    if isTrue ${NEEDS_PARTITIONING}; then
        logDebug "Harddisk needs formatting";
        return 1;
    fi;

    logDebug "Harddisk needs NO formatting";
    return 0;
}

# exprots PART_SYSTEM, PART_EFI, PART_BIOS
function harddisk-format {
    # Scan Arguments
    local ARG_HARDDISK="";
    local ARG_CRYPT="false";
    local ARG_CRYPT_PASSWORD="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --crypt) ARG_CRYPT="$2"; shift;;
            --crypt-password) ARG_CRYPT_PASSWORD="$2"; shift;;
            --harddisk) ARG_HARDDISK="$2"; shift;;
            *) logError "harddisk-format#Unknown Argument: $1"; return 1;;
        esac;
        shift;
    done;
    
    # Autodetect ${HARDDISK}
    if ! autodetect-harddisk --harddisk "${ARG_HARDDISK}"; then logError "Could not format harddisk. No Harddisk specified"; return 1; fi;

    # Validate Parameters
    if isTrue ${ARG_CRYPT}; then
        if [[ -z "${ARG_CRYPT_PASSWORD}" ]]; then
            logError "Must specify a password for crypto";
            return 1;
        fi;
    fi;

    # Remember partitions
    export PART_EFI="${HARDDISK}2"
    export PART_BOOT="${HARDDISK}3"
    export PART_SYSTEM="${HARDDISK}4"
    export PART_SYSTEM_NUM="4"
    
    # Check if drive is formatted already
    if harddisk-format-check --crypt "${ARG_CRYPT}" --harddisk "${HARDDISK}"; then return 0; fi;

    # Format drives
    logLine "Partitioning ${HARDDISK} with default partition scheme (bios and efi support)...";
    sfdisk -q ${HARDDISK} &> /dev/null <<- EOM
label: gpt
unit: sectors

start=2048, size=20480, type=21686148-6449-6E6F-744E-656564454649, bootable
start=22528, size=204800, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="efi"
start=227328, size=512000, type=BC13C2FF-59E6-4262-A352-B275FD6F7172, name="boot"
start=739328, size=512000, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="system"
EOM
    
    # Check Result
    if [ $? -ne 0 ]; then
        logLine "Failed to partition ${HARDDISK}";
        return 1;
    fi;
    
    # Resize to maximum space
    if ! runCmd parted -s ${HARDDISK} resizepart ${PART_SYSTEM_NUM} 100%; then logError "Failed to expand ROOT-Partition"; return 1; fi;
    
    # Sync drives
    sleep 1
    sync
    sleep 1

    # Format EFI-Partition
    if [[ ! -z "${PART_EFI}" ]]; then
        logLine "Formatting EFI-Partition (${PART_EFI})...";
        if ! runCmd mkfs.vfat -F32 ${PART_EFI}; then logError "Failed to Format EFI-Partition."; return 1; fi;
        if ! runCmd fatlabel ${PART_EFI} EFI; then logError "Failed to label EFI-Partition."; return 1; fi;
    fi;

    # Format BOOT-Partition
    logLine "Formatting BOOT-Partition (${PART_BOOT})...";
    if ! runCmd mkfs.ext2 -F -L boot ${PART_BOOT}; then logError "Failed to format BOOT-Partition"; return 1; fi;

    # Encrypt SYSTEM-Partition
    if isTrue ${ARG_CRYPT}; then
        if [[ ! -f /tmp/crypto.key ]]; then
            logLine "Generating Crypto-KEY...";
            if ! runCmd dd if=/dev/urandom of=/tmp/crypto.key bs=1024 count=1; then logError "Failed to generate Crypto-KEY"; return 1; fi;
        fi;
        
        logLine "Encrypting SYSTEM-Partition (${PART_SYSTEM})...";
        if ! runCmd cryptsetup --batch-mode luksFormat --type luks2 --cipher aes-xts-plain64 --key-size 256 --hash sha256 --pbkdf argon2i -d /tmp/crypto.key ${PART_SYSTEM}; then logError "Failed to cryptformat SYSTEM-Partiton"; return 1; fi;
        if ! runCmd cryptsetup --batch-mode open ${PART_SYSTEM} cryptsystem -d /tmp/crypto.key; then logError "Failed to open CRYPTSYSTEM-Partition"; return 1; fi;
        
        # Backup luks header
        rm -f /tmp/crypto.header &> /dev/null
        if ! runCmd cryptsetup luksHeaderBackup ${PART_SYSTEM} --header-backup-file /tmp/crypto.header; then logError "Failed to Backup LUKS-Header"; return 1; fi;
        
        # Add Password
        echo ${ARG_CRYPT_PASSWORD} | cryptsetup --batch-mode luksAddKey ${PART_SYSTEM} -d /tmp/crypto.key; 
        if [ $? -ne 0 ]; then logError "Failed to add password to SYSTEM-Partition"; return 1; fi;
        
        # Remap partition to crypted one
        export PART_SYSTEM="/dev/mapper/cryptsystem"
    fi;

    # Format Partition
    logLine "Formatting SYSTEM-Partition";
    if ! runCmd mkfs.btrfs -f -L system ${PART_SYSTEM}; then logError "Failed to format SYSTEM-Partition"; exit 1; fi;
    return 0;
}
