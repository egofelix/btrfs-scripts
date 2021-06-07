#!/bin/bash
function containsIllegalCharacter {
    if [[ "${1}" =~ ^[A-Za-z0-9\- _]+$ ]];
    then
        # Validated
        return 0;
    else
        return 1;
    fi;
}

function removeTrailingChar {
    local RESULT="${1}";
    if [[ "${1}" = *"${2}" ]]; then RESULT="${RESULT::-1}"; fi;
    echo "${RESULT}";
}

function removeLeadingChar {
    local RESULT="${1}";
    if [[ "${1}" = "${2}"* ]]; then RESULT="${RESULT:1}"; fi;
    echo "${RESULT}";
}

function isEmpty {
    if [[ -z "${1:-}" ]]; then return 0; fi;
    return 1;
}