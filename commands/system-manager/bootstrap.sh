#!/bin/bash
function printHelp {
    echo "Usage: ${ENTRY_SCRIPT} [-q|--quiet] ${ENTRY_COMMAND} [--distro <volume>]";
}

function run {
    echo "Todo";
    printHelp;
    exit 1;
}

run $@;
exit 0;