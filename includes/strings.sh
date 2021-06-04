#!/bin/bash
function containsIllegalCharacter {
  local ILLEGALCHARACTERS=("." "$" "&" "(" ")" "{" "}" "[" "]" ";" "<" ">" "\`" "|" "*" "?" "\"" "'" "*" "\\" "/" "+")
  for CHAR in "${ILLEGALCHARACTERS[@]}"
  do
    if [[ "$1" == *"${CHAR}"* ]]; then return 0; fi;
  done;
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