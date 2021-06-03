#!/bin/bash
set -uo pipefail;

############### Main Script ################
function printManagerHelp() {
    echo "Usage: ${ENTRY_SCRIPT} [-q|--quiet] [-n|--name <clienthostname>] [-s|--server ssh://user@host:port] <command> [<commandargs>]";
    echo "";
    echo "Possible commands are:";
    echo "";
}

# Scan arguments & command
function manager() {
    ## Load Functions
    local SCRIPT_SOURCE=$(readlink -f ${BASH_SOURCE});
    
    # Include Functions
    source "${SCRIPT_SOURCE%/*}/includes/functions.sh";
    #for f in ${SCRIPT_SOURCE%/*}/includes/functions/global/*.sh; do source $f; done;
    
    local ENTRY_PATH="${SCRIPT_SOURCE%/*}";
    local ENTRY_SCRIPT=$(basename $BASH_SOURCE);
    local ENTRY_COMMAND=""
    local SSH_URI=""
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --debug) DEBUG="true"; VERBOSE="true";;
            --verbose) VERBOSE="true";;
            -q|--quiet) QUIET="true"; QUIETPS=" &>/dev/null";;
            -n|--name) CLIENTHOSTNAME="$2"; shift;;
            -s|--server) SSH_URI="$2"; shift;;
            -h|--help) printManagerHelp; exit 0;;
            -*) logError "Unknown Argument: $1"; printManagerHelp; exit 1;;
            *) ENTRY_COMMAND="${1}"; shift; break;;
        esac;
        shift;
    done;
    
    # Force root
    stopIfNotElevated;
    
    # Proxy
    loadFunction commandLineProxy;
    if ! commandLineProxy --command-name "command" --command-value "${ENTRY_COMMAND:-}" --command-path "${SCRIPT_SOURCE%/*}/commands/" $@; then printReceiverHelp; exit 1; fi;
}

manager $@;
exit 0;