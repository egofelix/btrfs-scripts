#!/bin/bash
function runCmd {
    logDebug "Executing \`$@\`";
    
    export RUNCMD_CONTENT=""
    export RUNCMD_RETURNCODE=1
    RUNCMD_CONTENT=$(LC_ALL=C $@ 2>&1)
    RUNCMD_RETURNCODE=$?
    
    if [ ${RUNCMD_RETURNCODE} -ne 0 ]; then
        logDebug "Failed Command: \`$@\` Result: ${RUNCMD_CONTENT}";
        return 1;
    else
        if [ ! -z "${RUNCMD_CONTENT}" ]; then
            logSuccess "Executed \`$@\` Output: ${RUNCMD_CONTENT}";
        else
            logSuccess "Executed \`$@\`";
        fi;
        
        return 0;
    fi;
}

function ensureRoot {
    # Force root
    if [[ "${EUID:-}" -ne 0 ]]; then
        logError "Please run as root"; exit 1;
    fi;
}