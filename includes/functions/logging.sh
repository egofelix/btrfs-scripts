#!/bin/bash
function logDebug {
  if isTrue "${DEBUG:-}"; then
    echo -en "\033[01;95m" && echo -n "[DEBUG] $@" && echo -e "\e[0m";
  fi;
}

function logSuccess {
  if isTrue "${DEBUG:-}"; then
    echo -en "\033[01;92m" && echo -n "[DEBUG] $@" && echo -e "\e[0m";
  fi;
}

function logWarn {
  echo -en "\033[01;93m" && echo -n "[WARN] $@" && echo -e "\e[0m";
}

function logLine {
  if isTrue "${QUIET:-}"; then return; fi;
  echo $@;
}

function logError {
  echo -en "\033[01;31m" && echo -n "[ERROR] $@" && echo -e "\e[0m";
}