#!/bin/bash
function printReceiverSubCommandHelp() {
    echo "Usage: ${HOST_NAME} test";
    echo "";
    echo "Returns success if the client works.";
}

# test
function receiverSubCommand() {
    # Scan Arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -h|--help) printReceiverSubCommandHelp; exit 0;;
            *) logError "Unknown Argument: $1"; printReceiverSubCommandHelp; exit 1;;
        esac;
        shift;
    done;
    
    # all fine
    logLine "success";
    exit 0;
}

receiverSubCommand $@;
exit 0;