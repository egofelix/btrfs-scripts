#!/bin/bash

# serverDetect [--harddisk "<harddisk>"]
# Sets: HARDDISK
function autodetect-harddisk {
    # Scan Arguments
    local ARG_HARDDISK="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --harddisk) ARG_HARDDISK="$2"; shift;;
            *) logError "autodetect-harddisk#Unknown Argument: $1"; return 1;;
        esac;
        shift;
    done;
    
    # Search BACKUPVOLUME via Environment or AutoDetect
    if isEmpty "${ARG_HARDDISK:-}"; then ARG_HARDDISK=$(LC_ALL=C fdisk -l | grep 'Disk \/dev\/' | grep -v 'loop' | grep -v 'mapper' | awk '{print $2}' | awk -F':' '{print $1}' | sort | uniq | head -n 1); fi;
    if isEmpty "${ARG_HARDDISK}"; then logWarn "Failed to autodetect @backups directory."; return 1; fi;
    
    # Validate
    ARG_HARDDISK=$(removeTrailingChar "${ARG_HARDDISK}" "/");
    export HARDDISK="${ARG_HARDDISK}";
    logDebug "Validating HARDDISK: ${HARDDISK}";
    
    # Test if this drive is mounted under /*
    if ! runCmd findmnt -r; then logError "Could not detect rootfs mounts"; exit 1; fi;
    local DRIVEMOUNTS=$(echo "${RUNCMD_CONTENT,,}" | cut -d' ' -f 2 | grep "${HARDDISK}");
    if ! isEmpty ${DRIVEMOUNTS}; then
        logWarn "<harddisk> ${HARDDISK} is currently mounted and cannot be used as target. This value will be ignored.";
        return 1;
    fi;
    
    return 0;
}