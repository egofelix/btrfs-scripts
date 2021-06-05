#!/bin/bash
function printHelp {
    echo "Usage: ${HOST_NAME}${HOST_ARGS} ${COMMAND_VALUE} [--distro <volume>]";
}

function run {
    echo "Todo";
    printHelp;
    exit 1;
}

run $@;
exit 0;