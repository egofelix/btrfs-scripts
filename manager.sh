#!/bin/bash
set -uo pipefail;

############### Main Script ################
function printManagerArgs() {
    echo -n "[-q|--quiet] [-v|--verbose] [-d|--debug] <command> [<commandargs>]";
}

function printManagerHelp() {
    echo -en "Usage: ";
    printUsage ${ENTRY_SCRIPT} $(printManagerArgs);
    
    echo "";
    echo -en "To get more information about commands try: ";
    printUsage ${ENTRY_SCRIPT} "<command>" "--help";
    
    echo "";
    echo "Possible commands are:";
    printCommandLineProxyHelp --command-path "${SCRIPT_SOURCE%/*}/commands/";
    echo "";
}

# Scan arguments & command
function manager() {
    ## Load Functions
    local SCRIPT_SOURCE=$(readlink -f ${BASH_SOURCE});
    
    # Include Functions
    for f in ${SCRIPT_SOURCE%/*}/includes/*.sh; do source $f; done;
    
    # Scan Arguments
    local LOGDEFINED="false";
    local DEBUG="false";
    local QUIET="false";
    local QUIETPS="";
    local VERBOSE="false";
    local ENTRY_PATH="${SCRIPT_SOURCE%/*}";
    local ENTRY_SCRIPT=$(basename $BASH_SOURCE);
    local ENTRY_COMMAND="";
    local ENTRY_ARGS="$(printManagerArgs)";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -d|--debug) if isTrue ${LOGDEFINED}; then logError "Cannot mix --debug with --verbose or --quiet"; exit 1; fi; LOGDEFINED="true"; DEBUG="true"; VERBOSE="true";;
            -v|-verbose) if isTrue ${LOGDEFINED}; then logError "Cannot mix --debug with --verbose or --quiet"; exit 1; fi; LOGDEFINED="true"; VERBOSE="true";;
            -q|--quiet) if isTrue ${LOGDEFINED}; then logError "Cannot mix --debug with --verbose or --quiet"; exit 1; fi; LOGDEFINED="true"; QUIET="true"; QUIETPS=" &>/dev/null";;
            -h|--help) printManagerHelp; exit 0;;
            -*) logError "Unknown Argument: $1"; printManagerHelp; exit 1;;
            *) ENTRY_COMMAND="${1}"; shift; break;;
        esac;
        shift;
    done;
    
    # Check Root
    if [[ "$EUID" -ne 0 ]]; then logError "Please run as root"; exit 1; fi;
    
    # Proxy
    if ! commandLineProxy --command-name "command" --command-value "${ENTRY_COMMAND:-}" --command-path "${SCRIPT_SOURCE%/*}/commands/" $@; then printManagerHelp; exit 1; fi;
}

manager $@;
exit 0;