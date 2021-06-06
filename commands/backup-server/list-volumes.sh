#!/bin/bash
function printReceiverSubCommandHelp() {
    echo "Todo";
}

# list-snapshots -v|--volume <volume>
function receiverSubCommand() {
    # Scan Arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -h|--help) printReceiverSubCommandHelp; exit 0;;
            *) logError "Unknown Argument: $1"; printReceiverSubCommandHelp; exit 1;;
        esac;
        shift;
    done;
    
    # Test and return
    if ! runCmd ls -1d ${BACKUPVOLUME}/*/; then
        logError "Could not list volume: ${RUNCMD_CONTENT}";
        exit 1;
    fi;
    
    echo "${RUNCMD_CONTENT}" | grep -oP '[A-Za-z\-]*/$' | cut -d'/' -f 1;
    exit 0;
}

receiverSubCommand $@;
exit 0;