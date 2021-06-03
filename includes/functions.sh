#!/bin/bash
for f in ${BASH_SOURCE%/*}/functions/global/*.sh; do source $f; done

function loadFunction {
    if [[ -z $1 ]]; then return 1; fi;
    
    while [[ "$#" -gt 0 ]]; do
        if containsIllegalCharacter $1; then logError "Could not load function \"$1\""; return 1; fi;
        
        # Check if function is defined already
        type "$1" &>/dev/null && return 0;
        type "${1,,}" &>/dev/null && return 0;
        
        local FILENAME="${BASH_SOURCE%/*}/functions/${1}.sh";
        if [[ ! -f $FILENAME ]]; then FILENAME="${BASH_SOURCE%/*}/functions/${1,,}.sh"; fi;
        if [[ ! -f $FILENAME ]]; then return 1; fi;
        logDebug "Loading Function \"$1\" from \"$FILENAME\"";
        source $FILENAME;
        shift;
    done;
    
    
    return 0;
}