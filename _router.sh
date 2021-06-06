#!/bin/bash
set -uo pipefail;

function printHelp() {
    echo -en "Usage: ";
    printUsage "$(basename ${HOST_SCRIPT}) [-q|--quiet] [-v|--verbose] [-d|--debug] <host-command> [<commandargs>]";
    
    echo "";
    echo -en "To get more information about commands try: ";
    printUsage ${HOST_SCRIPT} "<command>" "--help";
    
    echo "";
    echo "Possible commands are:";
    printCommandLineProxyHelp --command-path "${SCRIPT_SOURCE%/*}/commands/";
    echo "";
}

# Scan arguments & command
function _router() {
    ## Load Functions
    local SCRIPT_SOURCE=$(readlink -f ${BASH_SOURCE});
    for f in ${SCRIPT_SOURCE%/*}/includes/*.sh; do source $f; done;
    
    # Scan Arguments
    local LOGDEFINED="false";
    local DEBUG="false";
    local QUIET="false";
    local QUIETPS="";
    local VERBOSE="false";
    local ENTRY_PATH="${SCRIPT_SOURCE%/*}";
    local ENTRY_SCRIPT=$(basename $BASH_SOURCE);
    local HOST_SCRIPT="";
    local HOST_COMMAND="";
    
    local HOST_HELP="false";
    local HOST_HELP_FLAG="";
    for var in "$@"
    do
        if [[ "$var" == "--help" ]];
        then
            HOST_HELP="true";
            HOST_HELP_FLAG=" --help";
        fi;
    done
    
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -d|--debug) if isTrue ${LOGDEFINED}; then logError "Cannot mix --debug with --verbose or --quiet"; exit 1; fi; LOGDEFINED="true"; DEBUG="true"; VERBOSE="true";;
            -v|-verbose) if isTrue ${LOGDEFINED}; then logError "Cannot mix --debug with --verbose or --quiet"; exit 1; fi; LOGDEFINED="true"; VERBOSE="true";;
            -q|--quiet) if isTrue ${LOGDEFINED}; then logError "Cannot mix --debug with --verbose or --quiet"; exit 1; fi; LOGDEFINED="true"; QUIET="true"; QUIETPS=" &>/dev/null";;
            -h|--help) ;;
            --host-script) HOST_SCRIPT="${2}"; shift;;
            -*) logError "Unknown Argument: $1"; exit 1;;
            *)
                HOST_COMMAND="$1";
                shift;
                break;
            ;;
        esac;
        shift;
    done;
    
    if isEmpty ${HOST_SCRIPT}; then logError "Please provide a host script, this script is not intended to be called by user"; exit 1; fi;
    if isEmpty ${HOST_COMMAND}; then logError "Please provide a host script, this script is not intended to be called by user"; exit 1; fi;
    local HOST_NAME=$(basename ${HOST_SCRIPT});
    
    if isEmpty "${HOST_COMMAND}" && isTrue "${HOST_HELP}"; then
        printHelp;
        exit 0;
    fi;
    
    if ! isTrue  "${HOST_HELP}"; then
        # Check Root
        if [[ "$EUID" -ne 0 ]]; then logError "Please run as root"; exit 1; fi;
    fi;
    
    if ! commandLineProxy --command-name "host-command" --command-value "${HOST_COMMAND}" --command-path "${SCRIPT_SOURCE%/*}/commands/" $@; then printHelp; exit 1; fi;
}

_router $@;
exit 0;