#!/bin/bash

function harddisk-format {
    # Scan Arguments
    local ARG_HARDDISK="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --harddisk) ARG_HARDDISK="$2"; shift;;
            *) logError "autodetect-harddisk#Unknown Argument: $1"; return 1;;
        esac;
        shift;
    done;
    
    # Autodetect ${HARDDISK}
    if ! autodetect-harddisk --harddisk "${ARG_HARDDISK}"; then logError "Could not format harddisk. No Harddisk specified"; return 1; fi;
    
    # Format drives
    logLine "Partitioning ${HARDDISK}...";
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
    
    return 0;
}
