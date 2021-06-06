#!/bin/bash
#commandLineProxy --command-name <command-name> --command-value <command-value> --command-path <command-path> args
function commandLineProxy {
    # Scan Arguments
    local COMMAND_NAME="";
    local COMMAND_VALUE="";
    local COMMAND_VALUE_DEFINED="false";
    local COMMAND_PATH="";
    
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --command-name) COMMAND_NAME="$2"; shift;;
            --command-value) COMMAND_VALUE="$2"; COMMAND_VALUE_DEFINED="true"; shift;;
            --command-path) COMMAND_PATH="$2"; shift;;
            *)
                if isEmpty "${COMMAND_NAME}"; then logError "<command-name> must be provided."; exit 1; fi;
                if isEmpty "${COMMAND_PATH}"; then logError "<command-path> must be provided."; exit 1; fi;
                if ! isTrue ${COMMAND_VALUE_DEFINED}; then logError "<command-value> must be provided."; exit 1; fi;
                break;
        esac;
        shift;
    done;
    
    # Debug Variables
    logFunction "commandLineProxy#arguments --command-name \"${COMMAND_NAME}\" --command-value \"${COMMAND_VALUE}\" --command-path \"${COMMAND_PATH}\" $@";
    
    # Validate Variables
    if isEmpty "${COMMAND_NAME}"; then logError "<command-name> must be provided."; exit 1; fi;
    if isEmpty "${COMMAND_PATH}"; then logError "<command-path> must be provided."; exit 1; fi;
    
    # Validate COMMAND_VALUE is save to use
    if isEmpty "${COMMAND_VALUE:-}"; then logError "<${COMMAND_NAME}> must be provided."; return 1; fi;
    if containsIllegalCharacter "${COMMAND_VALUE}"; then logError "Illegal character detected in <${COMMAND_NAME}> \"${COMMAND_VALUE}\"."; return 1; fi;
    if [[ "${COMMAND_VALUE,,}" == "help" ]]; then return 1; fi;
    
    # Check if subcommand exists
    if [ -f "${COMMAND_PATH}" ]; then
        local COMMAND_SCRIPT="${COMMAND_PATH%/*}/${COMMAND_VALUE,,}.sh";
    else
        local COMMAND_SCRIPT="${COMMAND_PATH}${COMMAND_VALUE,,}/_router.sh";
    fi;
    
    if [[ ! -f "${COMMAND_SCRIPT}" ]]; then
        logError "Unknown <${COMMAND_NAME}>: ${COMMAND_VALUE}";
        logDebug "Exptected Filename: ${COMMAND_SCRIPT}";
        return 1;
    fi;
    
    # Call Subcommand
    source "${COMMAND_SCRIPT}";
    return 0;
}

#printCommandLineProxyHelp --command-path <command-path> args
function printCommandLineProxyHelp {
    # Scan Arguments
    local COMMAND_PATH="";
    
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --command-path) COMMAND_PATH="$2"; shift;;
            *) logError "Unknown Argument: $1"; exit 1;;
        esac;
        shift;
    done;
    
    # Debug Variables
    logFunction "printCommandLineProxyHelp#arguments --command-path \"${COMMAND_PATH}\"";
    
    # Validate Variables
    if isEmpty "${COMMAND_PATH}"; then logError "<command-path> must be provided."; exit 1; fi;
    
    # Check if subcommand exists
    if [ -f "${COMMAND_PATH}" ]; then
        # via router
        local ROUTER=$(basename $COMMAND_PATH);
        local F="";
        for F in $(LC_ALL=C ls "${COMMAND_PATH%/*}" | sort); do
            if [[ "${F}" == "${ROUTER}" ]]; then continue; fi;
            
            F=${F%.*};
            echo " - ${F}";
        done;
    else
        # via entry
        local F="";
        for F in $(LC_ALL=C ls "${COMMAND_PATH%.*}" | sort); do
            if containsIllegalCharacter "${F%.*}"; then continue; fi;
            echo " - ${F%.*}";
        done;
    fi;
    
}