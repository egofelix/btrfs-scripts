#!/bin/bash
function printReceiverSubCommandHelp() {
    echo "Todo";
}

# check-volume -v|--volume <volume> -s|--snapshot <snapshot>
function receiverSubCommand() {
    # Scan Arguments
    local VOLUME="";
    local SNAPSHOT="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -h|--help) printReceiverSubCommandHelp; exit 0;;
            -v|--volume) VOLUME="$2"; shift;;
            -s|--snapshot) SNAPSHOT="$2"; shift;;
            *) logError "Unknown Argument: $1"; printReceiverSubCommandHelp; exit 1;;
        esac;
        shift;
    done;
    
    # Validate
    if [[ -z "${VOLUME}" ]]; then logError "<volume> cannot be empty"; printReceiverSubCommandHelp; exit 1; fi;
    if containsIllegalCharacter ${VOLUME}; then logError "Illegal character detected in <volume> \"${VOLUME}\"."; exit 1; fi;
    if [[ -z "${SNAPSHOT}" ]]; then logError "<snapshot> cannot be empty"; printReceiverSubCommandHelp; exit 1; fi;
    if containsIllegalCharacter ${SNAPSHOT}; then logError "Illegal character detected in <snapshot> \"${SNAPSHOT}\"."; exit 1; fi;
    
    # Test and return
    if [[ ! -d "${BACKUPVOLUME}/${VOLUME}/${SNAPSHOT}" ]]; then
        echo "false";
        exit 0;
    fi;
    echo "true";
    exit 0;
}

receiverSubCommand $@;
exit 0;