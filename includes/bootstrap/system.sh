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
    if [[ "${SYSNAME^^}" = *"ARCH"* ]]; then
        echo -n "ARCHLINUX";
        elif [ -f "/etc/arch-release" ]; then
        # Fallback detection
        echo -n "ARCHLINUX";
        elif [[ "${SYSNAME^^}" = *"DEBIAN"* ]]; then
        echo -n "DEBIAN";
        elif [[ "${SYSNAME^^}" = *"ALPINE"* ]]; then
        echo -n "ALPINE";
    else
        local SYSNAME=$(cat /etc/os-release)
        
        if [[ "${SYSNAME^^}" = *"ARCH"* ]]; then
            echo -n "ARCHLINUX";
            elif [[ "${SYSNAME^^}" = *"DEBIAN"* ]]; then
            echo -n "DEBIAN";
            elif [[ "${SYSNAME^^}" = *"ALPINE"* ]]; then
            echo -n "ALPINE";
        else
            echo -n "UNKNOWN";
        fi;
    fi;
}

function system-arch {
    local DISTIDENTIFIER=$(uname -m)
    if [[ "${DISTIDENTIFIER^^}" = "ARMV7L" ]]; then
        echo -n "ARMHF";
    else
        echo -n "AMD64";
    fi;
}