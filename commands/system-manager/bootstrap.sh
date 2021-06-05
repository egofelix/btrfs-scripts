#!/bin/bash
function printHelp {
    echo "Usage: ${HOST_NAME} ${COMMAND_VALUE} [-nc|--nocrypt] [-t|-target <targetdrive>] [-d|--distro <volume>]";
}

function run {
    # Scan Arguments
    local NOCRYPT="false"; local NOCRYPT_FLAG="";
    local TARGET_DRIVE="";
    local DISTRO="archlinux";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -t|--target) TARGET_DRIVE="$2"; shift ;;
            -d|--distro) DISTRO="$2"; shift ;;
            -nc|--nocrypt) NOCRYPT="true"; NOCRYPT_FLAG=" --nocrypt";;
            -h|--help) printHelp; exit 0;;
            *) logError "Unknown argument $1"; printHelp; exit 1;;
        esac;
        shift;
    done;
    
    # Debug Variables
    logFunction "bootstrap#arguments${NOCRYPT_FLAG} --target \`${TARGET_DRIVE}\` --distro \`${DISTRO}\`";
    
    # Test if we are running a live iso
    local IS_LIVE="false";
    if ! runCmd "findmnt -n / -r | cut -d' ' -f 2"; then logError "Could not detect rootfs type"; exit 1; fi;
    case "${RUNCMD_CONTENT,,}" in
        airootfs) IS_LIVE="true";;
        *) IS_LIVE="false";;
    esac;
    
    echo "Todo: ${IS_LIVE}";
    printHelp;
    exit 1;
}

run $@;
exit 0;