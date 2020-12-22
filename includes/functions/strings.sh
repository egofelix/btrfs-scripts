#!/bin/bash
function removeTrailingChar {
  RESULT="${1}";
  if [[ "${1}" = *"${2}" ]]; then RESULT="${RESULT::-1}"; fi;
  echo "${RESULT}";
}

function isEmpty {
  if [[ -z "${1:-}" ]]; then 
    logDebug "isEmpty with \"${1:-}\": 0.";
    return 0; 
  fi;
  
  logDebug "isEmpty with \"${1:-}\": 1.";
  return 1;
}