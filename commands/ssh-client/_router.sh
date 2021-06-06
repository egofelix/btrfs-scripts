#!/bin/bash
function printHelp() {
    echo "Usage: ${HOST_NAME} -t|--target <backupvolume> <client-command> <client-command-args...>";
    echo "";
    #echo "If you omit the <backupvolume> then the script will try to locate it with the subvolume name @backups.";
    #echo "If you omit the <ssh-uri> then the script will try to locate it via dns records.";
    #echo "If you omit the <snapshotvolume> then the script will try to locate it with the subvolume name @snapshots.";
    echo "    ${HOST_NAME} --target /.backups/user test";
    echo "      Returns success if the receiver works.";
    echo "";
    echo "Possible commands are:";
    printCommandLineProxyHelp --command-path "${BASH_SOURCE}";
}

# ssh-client -t|--target <backupvolume> <client-command> <client-command-args...>
function receiver() {
    #local LOGFILE="/tmp/receiver.log";
    
    
    # Scan Arguments
    local BACKUPVOLUME="";
    local RECEIVER_COMMAND="";
    local MANAGED="false";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --managed) MANAGED="true";;
            -t|--target) BACKUPVOLUME="$2"; shift;;
            -h|--help) printHelp; exit 0;;
            -*) logError "Unknown Argument: $1"; printHelp; exit 1;;
            *) RECEIVER_COMMAND="${1}"; shift; break;;
        esac;
        shift;
    done;
    
    if ! isTrue "${MANAGED}"; then
        logWarn "\`${ENTRY_SCRIPT} ssh-client\` should not be called by user direct, instead reference it in authorized_keys.";
    fi;
    
    # Debug Variables
    logFunction "receiver#arguments \`${RECEIVER_COMMAND}\`";
    
    # Validate
    if [[ -z "${RECEIVER_COMMAND}" ]]; then
        logError "No command specified";
        printHelp;
        exit 1;
    fi;
    
    # Validate
    if isEmpty ${BACKUPVOLUME}; then
        logError "<backupvolume> cannot be empty";
        printHelp;
        exit 1;
    fi;
    if ! autodetect-backupvolume --backupvolume "${BACKUPVOLUME}"; then logError "<backupvolume> cannot be empty"; exit 1; fi;
    #if [[ -z "${USERNAME}" ]]; then logError "<username> cannot be empty"; exit 1; fi;
    #if containsIllegalCharacter "${USERNAME}"; then logError "Illegal character detected in <username> \"${USERNAME}\"."; return 1; fi;
    
    # Proxy
    if ! commandLineProxy --command-name "client-command" --command-value "${RECEIVER_COMMAND:-}" --command-path "${BASH_SOURCE}" $@; then printHelp; exit 1; fi;
}

receiver $@;
exit 0;