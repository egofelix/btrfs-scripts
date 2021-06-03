#!/bin/bash
function logDebug {
    if ! isTrue "${DEBUG:-}"; then return; fi;
    echo -en "\033[02;98m" && echo -n "[DEBUG] [MSG] $@" && echo -e "\e[0m";
}

function logFunction {
    if ! isTrue "${DEBUG:-}"; then return; fi;
    echo -en "\033[01;96m" && echo -n "[DEBUG] [FUN] $@" && echo -e "\e[0m";
}

function logSuccess {
    if ! isTrue "${DEBUG:-}"; then return; fi;
    echo -en "\033[01;92m" && echo -n "[DEBUG] $@" && echo -e "\e[0m";
}

function logWarn {
    echo -en "\033[01;93m" && echo -n "[WARN] $@" && echo -e "\e[0m";
}

function logLine {
    if isTrue "${QUIET:-}"; then return; fi;
    echo $@;
}

function logVerbose {
    if isTrue "${QUIET:-}"; then return; fi;
    if ! isTrue "${VERBOSE:-}"; then return; fi;
    echo $@;
}

function logError {
    echo -en "\033[01;31m" && echo -n "[ERROR] $@" && echo -e "\e[0m";
}

function printUsage {
    while [[ "$#" -gt 0 ]]; do
        echo -en "\033[04;92m" && echo -n "${1}" && echo -en "\e[0m ";
        shift;
    done;
    echo "";
}