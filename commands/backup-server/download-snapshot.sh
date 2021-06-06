#!/bin/bash
function printReceiverSubCommandHelp() {
    echo "Todo";
}

# download-snapshot -v|--volume <volume> -s|--snapshot <snapshot>
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
    
    # Create Lockfile (Only one simultan instance per SNAPSHOTSPATH is allowed)
    if ! createLockFile --lockfile "${BACKUPVOLUME}/.$(basename $ENTRY_SCRIPT).lock"; then
        logError "Failed to lock lockfile \"${LOCKFILE}\". Maybe another action is running already?";
        exit 1;
    fi;
    
    # Check if the snapshot exists already
    if [[ ! -d "${BACKUPVOLUME}/${VOLUME}/${SNAPSHOT}" ]]; then logError "snapshot does not exists"; exit 1; fi;
    
    btrfs send -q ${BACKUPVOLUME}/${VOLUME}/${SNAPSHOT};
    if [[ $? -ne 0 ]]; then logError "Error sending snapshot."; exit 1; fi;
    exit 0;
}

receiverSubCommand $@;
exit 0;