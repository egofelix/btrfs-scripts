#!/bin/bash
function stopIfNotElevated {
    ## Script must be started as root
    if [[ "${EUID:-}" -ne 0 ]]; then
        logError "Please run as root"; exit 1;
    fi;
}