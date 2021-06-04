#!/bin/bash
function printReceiverHelp() {
    local MYARGS="-t|--target <backupvolume> <client-command> <client-command-args...>";
    local ARGS=${ENTRY_ARGS};
    ARGS="${ARGS/\<command\>/${ENTRY_COMMAND}}";
    ARGS="${ARGS/\[\<commandargs\>\]/${MYARGS}}";
    echo "Usage: ${ENTRY_SCRIPT} ${ARGS}";
    echo "";
    echo "    ${ENTRY_SCRIPT} ${ENTRY_COMMAND} --target /.backups/user test";
    echo "      Returns success if the receiver works.";
    echo "";
    
    echo "";
    echo "Possible commands are:";
    printCommandLineProxyHelp --command-path "${BASH_SOURCE}";
}

# ssh-client -t|--target <backupvolume> <client-command> <client-command-args...>
function receiver() {
    #local LOGFILE="/tmp/receiver.log";
    logWarn "\`${ENTRY_SCRIPT} ssh-client\` should not be called by user direct, instead reference it in authorized_keys.";
    
    # Scan Arguments
    local BACKUPVOLUME="";
    local RECEIVER_COMMAND="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -t|--target) BACKUPVOLUME="$2"; shift;;
            -h|--help) printReceiverHelp; exit 0;;
            -*) logError "Unknown Argument: $1"; printReceiverHelp; exit 1;;
            *) RECEIVER_COMMAND="${1}"; shift; break;;
        esac;
        shift;
    done;
    
    # Debug Variables
    logFunction "receiver#arguments \`${RECEIVER_COMMAND}\`";
    
    # Validate
    if [[ -z "${RECEIVER_COMMAND}" ]]; then
        logError "No command specified";
        printReceiverHelp;
        exit 1;
    fi;
    
    # Validate
    if isEmpty ${BACKUPVOLUME}; then
        logError "<backupvolume> cannot be empty";
        printReceiverHelp
        exit 1;
    fi;
    if ! autodetect-backupvolume --backupvolume "${BACKUPVOLUME}"; then logError "<backupvolume> cannot be empty"; exit 1; fi;
    #if [[ -z "${USERNAME}" ]]; then logError "<username> cannot be empty"; exit 1; fi;
    #if containsIllegalCharacter "${USERNAME}"; then logError "Illegal character detected in <username> \"${USERNAME}\"."; return 1; fi;
    
    # Proxy
    if ! commandLineProxy --command-name "client-command" --command-value "${RECEIVER_COMMAND:-}" --command-path "${BASH_SOURCE}" $@; then printReceiverHelp; exit 1; fi;
}

receiver $@;
exit 0;