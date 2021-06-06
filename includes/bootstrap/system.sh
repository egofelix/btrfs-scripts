#!/bin/bash

function system-is-efi {
    if [[ ! -d "/sys/firmware/efi" ]]; then
        return 1;
    else
        return 0;
    fi;
}


function system-model {
    local MODEL=$(dmesg | grep 'Machine model:' | grep -oP 'Machine\smodel\:.*' | awk -F':' '{print $2}')
    if [[ "${MODEL^^}" = *"CUBIETECH CUBIETRUCK"* ]]; then
        echo -n "CUBIETRUCK";
    else
        echo -n "UNKNOWN";
    fi;
}

function system-name {
    local SYSNAME=$(uname -a)
    local ID=""
    if [[ "${SYSNAME^^}" = *"ARCH"* ]];
    then
        ID="ARCHLINUX";
    elif [ -f "/etc/arch-release" ];
    then
        # Fallback detection
        ID="ARCHLINUX";
    elif [[ "${SYSNAME^^}" = *"DEBIAN"* ]];
    then
        ID="DEBIAN";
    elif [[ "${SYSNAME^^}" = *"ALPINE"* ]];
    then
        ID="ALPINE";
    else
        local SYSNAME=$(cat /etc/os-release)
        
        if [[ "${SYSNAME^^}" = *"ARCH"* ]]; then
            ID="ARCHLINUX";
        elif [[ "${SYSNAME^^}" = *"DEBIAN"* ]];
        then
            ID="DEBIAN";
        elif [[ "${SYSNAME^^}" = *"ALPINE"* ]];
        then
            ID="ALPINE";
        else
            ID="UNKNOWN";
        fi;
    fi;
    
    if [[ -z "${1:-}" ]]; then
        echo -n "${ID}";
        return 0;
    fi;
    
    if [[ "${1^^}" == "${ID}" ]]; then
        return 0;
    else
        return 1;
    fi;
}

function system-arch {
    local DISTIDENTIFIER=$(uname -m)
    local ID=""
    if [[ "${DISTIDENTIFIER^^}" = "ARMV7L" ]]; then
        ID="ARMHF";
    else
        ID="AMD64"
        echo -n "AMD64";
    fi;
    
    if [[ -z "${1:-}" ]]; then
        echo -n "${ID}";
        return 0;
    fi;
    
    if [[ "${1^^}" == "${ID}" ]]; then
        return 0;
    else
        return 1;
    fi;
}