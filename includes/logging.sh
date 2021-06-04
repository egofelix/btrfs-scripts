#!/bin/bash
function logDebug {
    if ! isTrue "${DEBUG:-}"; then return; fi;
    if [[ ! -z "${LOGFILE:-}" ]]; then echo "[DEBUG] [MSG] $@" >> ${LOGFILE}; fi;
    echo -en "\033[02;98m" && echo -n "[DEBUG] [MSG] $@" && echo -e "\e[0m";
}

function logFunction {
    if ! isTrue "${DEBUG:-}"; then return; fi;
    if [[ ! -z "${LOGFILE:-}" ]]; then echo "[DEBUG] [FUN] $@" >> ${LOGFILE}; fi;
    echo -en "\033[01;96m" && echo -n "[DEBUG] [FUN] $@" && echo -e "\e[0m";
}

function logSuccess {
    if ! isTrue "${DEBUG:-}"; then return; fi;
    if [[ ! -z "${LOGFILE:-}" ]]; then echo "[DEBUG] $@" >> ${LOGFILE}; fi;
    echo -en "\033[01;92m" && echo -n "[DEBUG] $@" && echo -e "\e[0m";
}

function logWarn {
    if [[ ! -z "${LOGFILE:-}" ]]; then echo "[WARN] $@" >> ${LOGFILE}; fi;
    if isTrue "${QUIET:-}"; then return; fi;
    echo -en "\033[01;93m" && echo -n "[WARN] $@" && echo -e "\e[0m";
}

function logLine {
    if [[ ! -z "${LOGFILE:-}" ]]; then echo "$@" >> ${LOGFILE}; fi;
    if isTrue "${QUIET:-}"; then return; fi;
    echo $@;
}

function logVerbose {
    if [[ ! -z "${LOGFILE:-}" ]]; then echo "$@" >> ${LOGFILE}; fi;
    if isTrue "${QUIET:-}"; then return; fi;
    if ! isTrue "${VERBOSE:-}"; then return; fi;
    echo $@;
}

function logError {
    if [[ ! -z "${LOGFILE:-}" ]]; then echo "[ERROR] $@" >> ${LOGFILE}; fi;
    echo -en "\033[01;31m" && echo -n "[ERROR] $@" && echo -e "\e[0m";
}

function printUsage {
    while [[ "$#" -gt 0 ]]; do
        echo -en "\033[04;92m" && echo -n "${1}" && echo -en "\e[0m ";
        shift;
    done;
    echo "";
}