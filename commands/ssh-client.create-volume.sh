#!/bin/bash
function printReceiverSubCommandHelp() {
    echo "Todo";
}

# create-volume [-v|--volume <volume>]
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
    
    # Debug Variables
    logFunction "receiver.create-volume --volume \`${VOLUME}\`";
    
    # Validate
    if [[ -z "${VOLUME}" ]]; then logError "<volume> cannot be empty"; exit 1; fi;
    if containsIllegalCharacter "${VOLUME}"; then logError "Illegal character detected in <volume> \"${VOLUME}\"."; return 1; fi;
    
    # Create Lockfile (Only one simultan instance per SNAPSHOTSPATH is allowed)
    if ! createLockFile --lockfile "${BACKUPVOLUME}/$(basename $ENTRY_SCRIPT).lock"; then
        logError "Failed to lock lockfile \"${LOCKFILE}\". Maybe another action is running already?";
        exit 1;
    fi;
    
    # Create directory
    if ! runCmd mkdir -p ${BACKUPVOLUME}/${VOLUME}; then logError "Failed to create volume directory."; exit 1; fi;
    
    # Done
    echo "success";
    exit 0;
}

receiverSubCommand $@;
exit 0;