#!/bin/bash
function getSystemType {
  local DISTIDENTIFIER=$(uname -m)
  if [[ "${DISTIDENTIFIER^^}" = "ARMV7L" ]]; then
    echo -n "ARMHF";
  else
    echo -n "AMD64";
  fi;
}