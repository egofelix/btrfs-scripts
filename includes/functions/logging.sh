#!/bin/bash
function logDebug {
  if isTrue "${DEBUG:-}"; then
    echo "[DEBUG] $@";
  fi;
}

function logWarn {
  echo "[WARN] $@";
}

function logLine {
  if isTrue "${QUIET:-}"; then return; fi;
  echo $@;
}

function logError {
  echo "[ERROR] $@";
}