#!/bin/bash
function removeTrailingChar {
  if [[ "${1}" = *"${2}" ]]; then
    return "${1::-1}";
  fi;
  
  return "${1}";
}