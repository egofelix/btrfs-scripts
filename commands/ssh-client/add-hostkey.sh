#!/bin/bash
function printHelp() {
    echo "Usage: ${ENTRY_SCRIPT} ${ENTRY_COMMAND} test";
    echo "";
    echo "Returns success if the client works.";
}

# test
function _main() {
    # Scan Arguments
    local KEY="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --key) KEY="$2"; shift;;
            -h|--help) printHelp; exit 0;;
            *) logError "Unknown Argument: $1"; printHelp; exit 1;;
        esac;
        shift;
    done;
    
    # Check if user is allowed to manage keys
    if ! isTrue ${KEY_MANAGER}; then
        logError "You are not allowed to manage keys.";
        exit 1;
    fi;
    
    if isEmpty "$KEY"; then
        logError "A key must be provided";
        exit 1;
    fi;
    
    # all fine
    logLine "failed";
    exit 1;
}

_main "$@";
exit 0;