#!/bin/bash
function containsIllegalCharacter {
    [[ "${1}" =~ ^[A-Za-z0-9\- _]+$ ]] && return 0;
    return 1;
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