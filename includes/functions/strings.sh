#!/bin/bash
function removeTrailingChar {
  RESULT="${1}";
  if [[ "${1}" = *"${2}" ]]; then RESULT="${RESULT::-1}"; fi;
  echo "${RESULT}";
}

function isEmpty {
  logDebug "called isEmpty with \"${1:-}\".";
  if [[ -z "${1:-}" ]]; then return 1; fi;
  return 0;
}