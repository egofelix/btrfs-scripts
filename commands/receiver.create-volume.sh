#!/bin/bash

function printReceiverSubCommandHelp() {
    echo "Todo";
}

# Command manager
# /manager.sh [-q|--quiet] [-n|--name <clienthostname>] [-s|--server ssh://user@host:port] create-volume <volume>
# Command create-volume
# -b|--backupvolume <backupvolume> <volume>
function receiverSubCommand() {
    # Scan Arguments
    local VOLUME="";
    local BACKUPVOLUME="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -b|--backupvolume) BACKUPVOLUME="$2"; shift;;
            *) if [[ -z "${VOLUME}" ]]; then
                    VOLUME="${1}";
                    if [[ -z "${VOLUME}" ]]; then
                        logError "<volume> cannot be empty"; printReceiverSubCommandHelp;
                        exit 1;
                    fi;
                fi;
        esac;
        shift;
    done;
    
    # Debug Variables
    logFunction "receiver.create-volume --volume \`${VOLUME}\`";
    
    # Validate
    if [[ -z "${VOLUME}" ]]; then logError "<volume> cannot be empty"; exit 1; fi;
    if containsIllegalCharacter "${VOLUME}"; then logError "Illegal character detected in <volume> \"${VOLUME}\"."; return 1; fi;
    
    # Detect Backupvolume;
    if ! autodetect-backupvolume; then
        logError "Could not detect <backupvolume>";
        exit 1;
    fi;
    
    # Ensure dir exists
    if ! runCmd mkdir -p ${BACKUPVOLUME}/${USERNAME}; then logError "Failed to create user directory."; exit 1; fi;
    
    # Create Lockfile (Only one simultan instance per SNAPSHOTSPATH is allowed)
    if ! createLockFile --lockfile "${BACKUPVOLUME}/${USERNAME}/$(basename $ENTRY_SCRIPT).lock"; then
        logError "Failed to lock lockfile \"${LOCKFILE}\". Maybe another action is running already?";
        exit 1;
    fi;
    
    # Create directory
    if ! runCmd mkdir -p ${BACKUPVOLUME}/${USERNAME}/${VOLUME}; then logError "Failed to create volume directory."; exit 1; fi;
    
    # Done
    logLine "success";
    exit 0;
}

receiverSubCommand $@;
exit 0;