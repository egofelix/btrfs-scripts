#!/bin/bash
function getSystemName {
  local SYSNAME=$(uname -a)
  if [[ "${SYSNAME^^}" = *"ARCH"* ]]; then
    echo -n "ARCHLINUX";
  elif [ -f "/etc/arch-release" ]; then
    # Fallback detection
    echo -n "ARCHLINUX";
  elif [[ "${SYSNAME^^}" = *"DEBIAN"* ]]; then
    echo -n "DEBIAN";
  elif [[ "${SYSNAME^^}" = *"ALPINE"* ]]; then
    echo -n "ALPINE";
  else
    local SYSNAME=$(cat /etc/os-release)

    if [[ "${SYSNAME^^}" = *"ARCH"* ]]; then
      echo -n "ARCHLINUX";
    elif [[ "${SYSNAME^^}" = *"DEBIAN"* ]]; then
      echo -n "DEBIAN";
    elif [[ "${SYSNAME^^}" = *"ALPINE"* ]]; then
      echo -n "ALPINE";
    else
      echo -n "UNKNOWN";
    fi;
  fi;
}