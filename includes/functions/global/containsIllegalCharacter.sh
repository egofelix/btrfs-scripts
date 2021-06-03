#!/bin/bash
function containsIllegalCharacter {
  local ILLEGALCHARACTERS=("." "$" "&" "(" ")" "{" "}" "[" "]" ";" "<" ">" "\`" "|" "*" "?" "\"" "'" "*" "\\" "/")
  for CHAR in "${ILLEGALCHARACTERS[@]}"
  do
    if [[ "$1" == *"${CHAR}"* ]]; then return 0; fi;
  done;
  return 1;
}