#!/bin/bash
function removeTrailingChar {
  RESULT="${1}";
  if [[ "${1}" = *"${2}" ]]; then RESULT="${RESULT::-1}"; fi;
  echo "${RESULT}";
}

function removeLeadingChar {
  RESULT="${1}";
  if [[ "${1}" = "${2}"* ]]; then RESULT="${RESULT:1}"; fi;
  echo "${RESULT}";
}

function isEmpty {
  if [[ -z "${1:-}" ]]; then return 0; fi;
  return 1;
}