#!/bin/bash
# Command manager
# /manager.sh [-q|--quiet] [-n|--name <clienthostname>] [-s|--server ssh://user@host:port] restore-snapshot
# Command restore-snapshot
# [--target <targetvolume>] [-s|--snapshot <snapshot>] [--test] <volume>
function restoreSnapshot {
    # Scan Arguments
    local TARGETVOLUME="";
    local SNAPSHOT="";
    local TEST="false";
    local TESTFLAG="";
    local VOLUME="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --target) TARGETVOLUME="$2"; shift;;
            -s|--snapshot) SNAPSHOT="$2"; shift;;
            --test) TEST="true"; TESTFLAG=" --test";;
            -h|--help) echo "Print snapshot help"; exit 0;;
            -*) echo "Unknown Argument: $1"; echo "PRint help here"; exit 1;;
            *)
                if [[ -z "${VOLUME}" ]]; then
                    VOLUME="${1}";
                    if [[ -z "${VOLUME}" ]]; then logError "<volume> cannot be empty"; exit 1; fi;
                fi;
        esac;
        shift;
    done;
    
    # Debug Variables
    logFunction "snapshotCommand --target \`${TARGETVOLUME}\` --snapshot \`${SNAPSHOT}\`${TESTFLAG} ${VOLUME}";
    
    # Validate
    if [[ -z "${VOLUME}" ]]; then logError "<volume> cannot be empty"; exit 1; fi;
    
    # Load Functions
    loadFunction serverDetect;
    
    # Detect Server
    if ! serverDetect --uri "${SSH_URI}" --hostname ""; then
        logError "snapshotCommand#Failed to detect server, please specify one with --source <uri>";
        exit 1;
    fi;
}


restoreSnapshot $@;
exit 0;