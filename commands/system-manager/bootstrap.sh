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
    
    # Validate HARDDISK
    if ! autodetect-harddisk --harddisk "${HARDDISK}"; then logError "Could not detect <harddisk>"; exit 1; fi;
    
    #Debug
    logFunction "bootstrap#expandedArguments${NOCRYPT_FLAG} --target \`${HARDDISK}\` --distro \`${DISTRO}\`";
    
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
    if ! harddisk-format-check --crypt "${CRYPT}" --crypt-mapper "/dev/mapper/cryptsystem" --harddisk "${HARDDISK}"; then
        read -p "You are now deleting all contents of \"${HARDDISK}\", continue? [yN]: " -n 1 -r
        echo    # (optional) move to a new line
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            logError "Script canceled by user";
            exit 1;
        fi;
        
        # Format Drive
        if ! harddisk-format --crypt "${CRYPT}" --crypt-password "${CRYPT_PASSWORD}" --harddisk "${HARDDISK}"; then
            logError "Failed to format ${HARDDISK}";
            exit 1;
        fi;
    fi;
    
    
    
    echo "Todo";
    printHelp;
    exit 1;
}

run $@;
exit 0;