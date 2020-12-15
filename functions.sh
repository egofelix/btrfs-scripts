#!/bin/bash
function isTrue {
	if [[ "${1^^}" = "YES" ]]; then return 0; fi;
	if [[ "${1^^}" = "TRUE" ]]; then return 0; fi;
	return 1;
}

function logLine {
	if isTrue "true"; then
        echo $@
	fi;
}

function isEfiSystem {
	if [[ ! -d "/sys/firmware/efi" ]]; then
		return 1;
	else
		return 0;
	fi;
}

function getSystemType {
  DISTIDENTIFIER=$(uname -m)
  if [[ "${DISTIDENTIFIER^^}" = "ARMV7L" ]]; then
    echo -n "ARMHF";
  else
    echo -n "AMD64";
  fi;
}

function getSystemName {
  SYSNAME=$(uname -a)
  if [[ "${SYSNAME^^}" = *"ARCH"* ]]; then
    echo -n "ARCHLINUX";
  else
    echo -n "UNKNOWN";
  fi;
}