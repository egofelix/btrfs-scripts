#!/bin/bash
function getSystemName {
  local SYSNAME=$(uname -a)
  if [[ "${SYSNAME^^}" = *"ARCH"* ]]; then
    echo -n "ARCHLINUX";
  elif [ -f "/etc/arch-release" ]; then
    # Fallback detection
    echo -n "ARCHLINUX";
  if [[ "${SYSNAME^^}" = *"DEBIAN"* ]]; then
    echo -n "DEBIAN";
  else
    echo -n "UNKNOWN";
  fi;
}