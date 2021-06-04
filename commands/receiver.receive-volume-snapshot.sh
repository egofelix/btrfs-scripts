#!/bin/bash
function printReceiverSubCommandHelp() {
    echo "Todo";
}

#!/bin/bash
# Command receiver check-volume
# /manager receiver check-volume -v|--volume <volume> -s|--snapshot <snapshot>
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
    if [[ -d "${BACKUPVOLUME}/${VOLUME}/${SNAPSHOT}" ]]; then logError "already exists"; exit 1; fi;
    
    # Trap for aborted receives (cleanup)
    _failedReceive() {
        logDebug "In failed Trap";
        if [[ -z "${RECEIVERESULT:-}" ]]; then
            local RECEIVERESULT=${RUNCMD_CONTENT:-};
        fi;
        
        logLine "Failed to receive snapshot: ${RECEIVERESULT}";
        # Remove broken subvolume
        SUBVOLCHECK=$(echo "${RECEIVERESULT}" | grep -P 'At (subvol|snapshot) ' | awk '{print $3}');
        if [[ ! -z "${SUBVOLCHECK}" ]]; then
            logDebug "Removing ${BACKUPVOLUME}/${VOLUME}/${SNAPSHOT}";
            if ! runCmd btrfs subvol del ${BACKUPVOLUME}/${VOLUME}/${SNAPSHOT}; then
                logError "Failed to Remove ${BACKUPVOLUME}/${VOLUME}/${SNAPSHOT}";
            fi;
        fi;
        
        # Exit
        logError "Receive failed."; exit 1;
    }
    trap _failedReceive EXIT SIGHUP SIGKILL SIGTERM SIGINT;
    
    # Receive
    logLine "Starting Receive..";
    if ! runCmd btrfs receive ${BACKUPVOLUME}/${VOLUME} < /dev/stdin; then
        RECEIVERESULT=${RUNCMD_CONTENT};
        logError "ARG";
        exit 1;
    fi;
    export RECEIVERESULT=${RUNCMD_CONTENT};
    logError "ARG2: ${RECEIVERESULT}";
    # Get name of received subvolume
    SUBVOLCHECK=$(echo "${RUNCMD_CONTENT}" | grep -P 'At (subvol|snapshot) ' | awk '{print $3}');
    if [[ -z "${SUBVOLCHECK}" ]]; then
        # Return error
        logError "failed to detect subvolume: \"${SUBVOLCHECK}\" in \"${RECEIVERESULT}\"."; exit 1;
    fi;
    
    if [[ "${SUBVOLCHECK}" != "${SNAPSHOT}" ]]; then
        # Return error and fire trap for removal
        logError "subvolume mismatch \"${SUBVOLCHECK}\" != \"${SNAPSHOT}\"."; exit 1;
    fi;
    
    # Restore Trap
    trap - EXIT SIGHUP SIGKILL SIGTERM SIGINT;
    trap _no_more_locking EXIT;
    
    # Snapshot received
    logDebug "Received --volume \"${VOLUME}\" --snapshot \"${SNAPSHOT}\"";
    echo "success"; exit 0;
}

receiverSubCommand $@;
exit 0;