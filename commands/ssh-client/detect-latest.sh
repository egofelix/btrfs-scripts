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
    
    # Loop over volumes
    local TARGETSNAPSHOT="";
    local VOLUMES=$(echo "${RUNCMD_CONTENT}" | grep -oP '[0-9A-Za-z\-\_]*/$' | cut -d'/' -f 1);
    logDebug Detected volumes: $(removeTrailingChar $(echo "${VOLUMES}" | tr '\n' ',') ',');
    for VOLUME in $(echo "${VOLUMES}" | sort)
    do
        if ! runCmd ls -1d ${BACKUPVOLUME}/${VOLUME}/*/; then
            logError "Failed to list volume \"${VOLUME}\"";
            exit 1;
        fi;
        
        local SNAPSHOTS=$(echo "${RUNCMD_CONTENT}" | grep -oP '[0-9A-Za-z\-\_]*/$' | cut -d'/' -f 1)
        logDebug Detected snapshots: $(removeTrailingChar $(echo "${SNAPSHOTS}" | tr '\n' ',') ',');
        
        local LASTSNAPSHOT=$(echo "${RUNCMD_CONTENT}" | grep -oP '[0-9A-Za-z\-\_]*/$' | cut -d'/' -f 1 | sort | tail -1);
        logDebug "Latest Snapshot for volume \"${VOLUME}\" is: \"${LASTSNAPSHOT}\"";
        
        local TARGETSNAPSHOT=$(echo -e "${LASTSNAPSHOT}\n${TARGETSNAPSHOT:-}" | sort | tail -1);
    done;
    
    if [[ -z "${TARGETSNAPSHOT}" ]]; then
        logError "Could not autodetect";
        exit 1;
    fi;
    
    echo "${TARGETSNAPSHOT}";
    exit 0;
}

receiverSubCommand $@;
exit 0;