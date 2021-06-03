#!/bin/bash
export LOCKFNAME="${LOCKFILE:-}";
export LOCKFD=-1;

function createLockFile() {
    # Scan Arguments
    local LOCKFILE="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --lockfile) LOCKFILE="$2"; shift;;
            *) logError "createLockFile#Unknown Argument: $1"; return 1;;
        esac;
        shift;
    done;
    
    # Debug Variables
    logFunction "createLockFile#arguments --lockfile \"${LOCKFILE}\"";
    
    # Autofill lockfile if missing
    if [[ -z ${LOCKFILE:-} ]]; then
        local LOCKFILE="/var/lock/btrfs-manager.lock";
    fi;
    
    # Debug
    logFunction "createLockFile#expandedArguments --lockfile \"${LOCKFILE}\"";
    
    # Main Func
    export LOCKFNAME="${LOCKFILE}";
    export LOCKFD=99;
    _lock() {
        flock -$1 $LOCKFD;
    }
    _no_more_locking() {
        logDebug "Removing LockFile $LOCKFNAME";
        _lock u;
        _lock xn && rm -f $LOCKFNAME;
    }
    _prepare_locking() {
        eval "exec $LOCKFD>\"$LOCKFNAME\"" >/dev/null 2>&1;
        if [[ $? -ne 0 ]]; then
            logError "Failed to create lock-file: ${LOCKFNAME}";
            exit 1;
            
        fi;
        trap _no_more_locking EXIT;
    }
    exlock_now() {
        _lock xn;
    }  # obtain an exclusive lock immediately or fail
    _prepare_locking
    local LOCKED=exlock_now
    if ! $LOCKED; then
        logError "Script is running already";
        exit 1;
    fi;
}