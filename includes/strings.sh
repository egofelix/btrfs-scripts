#!/bin/bash
function containsIllegalCharacter {
    $(echo "${1}" | grep -P '^[A-Za-z0-9 \-\_]+$');
    if [ $? -ne 0 ]; then
        return 1;
    else
        # Validated
        return 0;
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