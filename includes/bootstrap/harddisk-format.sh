#!/bin/bash

# exprots PART_SYSTEM, PART_EFI, PART_BIOS
function harddisk-format {
    # Scan Arguments
    local ARG_HARDDISK="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --harddisk) ARG_HARDDISK="$2"; shift;;
            *) logError "harddisk-format#Unknown Argument: $1"; return 1;;
        esac;
        shift;
    done;
    
    # Autodetect ${HARDDISK}
    if ! autodetect-harddisk --harddisk "${ARG_HARDDISK}"; then logError "Could not format harddisk. No Harddisk specified"; return 1; fi;
    
    # Check if we need partitioning?
    local NEEDS_PARTITIONING="false";
    if ! isTrue ${NEEDS_PARTITIONING} && runCmd blkid /dev/sda5; then NEEDS_PARTITIONING="true"; fi;
    if ! isTrue ${NEEDS_PARTITIONING} && ! runCmd blkid /dev/sda; then NEEDS_PARTITIONING="true"; fi;
    
    echo "PT: ${NEEDS_PARTITIONING}";
    
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
    
    # Remember partitions
    export PART_EFI="${HARDDISK}2"
    export PART_BOOT="${HARDDISK}3"
    export PART_SYSTEM="${HARDDISK}4"
    export PART_SYSTEM_NUM="4"
    
    if ! runCmd parted -s ${DRIVE_ROOT} resizepart ${PART_SYSTEM_NUM} 100%; then logError "Failed to expand ROOT-Partition"; return 1; fi;
    
    # Sync drives
    sleep 1
    sync
    sleep 1
    
    return 0;
}
