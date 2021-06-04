#!/bin/bash
function printReceiverSubCommandHelp() {
    echo "Usage:";
    echo "";
    echo -en "    ";
    printUsage ${ENTRY_SCRIPT} ${ENTRY_COMMAND} "test";
    echo "      Returns success if the receiver works.";
    echo "";
}
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