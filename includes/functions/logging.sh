#!/bin/bash
function logDebug {
  if isTrue "${DEBUG:-}"; then
    echo "[DEBUG] $@";
  fi;
}

function logLine {
  if isTrue "${QUIET:-}"; then return; fi;
  echo $@;
}

function logError {
  echo "[ERROR] $@";
}