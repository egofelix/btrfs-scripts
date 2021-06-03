#!/bin/bash
function printReceiverTestHelp() {
    echo "Todo";
}
function receiverTest() {
    # Scan Arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            *) logError "Unknown Argument: $1"; printReceiverTestHelp; exit 1;;
        esac;
        shift;
    done;
    
    # Create Lockfile (Only one simultan instance per SNAPSHOTSPATH is allowed)
    loadFunction createLockFile;
    if ! createLockFile --lockfile "${SNAPSHOTVOLUME}/.$(basename $ENTRY_SCRIPT).lock"; then
        logError "Failed to lock lockfile \"${LOCKFILE}\". Maybe another action is running already?";
        exit 1;
    fi;
    
    # all fine
    logLine "success";
    exit 0;
}

receiverTest $@;
exit 0;