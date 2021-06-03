#!/bin/bash
function createLockFile() {
    export LOCKFILE="/var/lock/btrfs-manager.lock";
    if isEmpty ${LOCKFILE:-}; then logError "LOCKFILE has to be filled"; exit 1; fi;
    
    LOCKFD=99
    _lock()             { flock -$1 $LOCKFD; }
    _no_more_locking()  { _lock u; _lock xn && rm -f $LOCKFILE; }
    _prepare_locking() {
        eval "exec $LOCKFD>\"$LOCKFILE\"" >/dev/null 2>&1;
        if [[ $? -ne 0 ]]; then
            logError "Failed to create lock-file: ${LOCKFILE}";
            exit 1;
            
        fi;
        trap _no_more_locking EXIT;
    }
    exlock_now()        { _lock xn; }  # obtain an exclusive lock immediately or fail
    _prepare_locking
    LOCKED=exlock_now
    if ! $LOCKED; then
        logError "Script is running already";
        exit 1;
    fi;
}