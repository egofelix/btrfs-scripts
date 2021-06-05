#!/bin/bash
function printHelp {
    echo "Usage: ${ENTRY_SCRIPT} [-q|--quiet] ${ENTRY_COMMAND} [--snapshotvolume <snapshotvolume>] [--server ssh://user@host:port] [--volume <volume>]";
}

function run {
    echo "TODO - Install Cronjob";
    printHelp;
    exit 1;
}


run $@;
exit 0;