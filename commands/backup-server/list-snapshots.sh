#!/bin/bash
function printReceiverSubCommandHelp() {
    echo "Todo";
}

# list-snapshots -v|--volume <volume>
function receiverSubCommand() {
    # Scan Arguments
    local VOLUME="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -h|--help) printReceiverSubCommandHelp; exit 0;;
            -v|--volume) VOLUME="$2"; shift;;
            *) logError "Unknown Argument: $1"; printReceiverSubCommandHelp; exit 1;;
        esac;
        shift;
    done;
    
    # Validate
    if [[ -z "${VOLUME}" ]]; then logError "<volume> cannot be empty"; printReceiverSubCommandHelp; exit 1; fi;
    if containsIllegalCharacter ${VOLUME}; then logError "Illegal character detected in <volume> \"${VOLUME}\"."; exit 1; fi;
    
    # Test and return
    if [[ ! -d "${BACKUPVOLUME}/${VOLUME}" ]]; then
        if ! runCmd mkdir -p ${BACKUPVOLUME}/${VOLUME}; then
            logError "<volume> \"${VOLUME}\" could not be created";
            exit 1;
        fi;
    fi;
    
    if ! runCmd ls ${BACKUPVOLUME}/${VOLUME}; then
        logError "Failed to list volume";
        exit 1;
    fi;
    
    echo ${RUNCMD_CONTENT};
    exit 0;
}

receiverSubCommand $@;
exit 0;