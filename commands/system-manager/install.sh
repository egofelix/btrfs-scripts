#!/bin/bash
function printHelp {
    echo "Usage: ${ENTRY_SCRIPT} [-q|--quiet] ${ENTRY_COMMAND} [--snapshotvolume <snapshotvolume>] [--server ssh://user@host:port] [--volume <volume>]";
}

function commandFunc {
    echo "TODO - Install Cronjob";
}


commandFunc $@;
exit 0;