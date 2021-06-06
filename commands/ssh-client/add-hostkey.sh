#!/bin/bash
function printHelp() {
    echo "Usage: ${HOST_NAME} add-hostkey <keydata>";
    echo "";
    echo "Returns success if the client works.";
}

# test
function _main() {
    # Scan Arguments
    local KEY="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -h|--help) printHelp; exit 0;;
            *) if isEmpty "${KEY}"; then KEY="$1"; else KEY="${KEY} $1"; fi;;
        esac;
        shift;
    done;
    
    # Check if user is allowed to manage keys
    if ! isTrue ${KEY_MANAGER}; then
        logError "You are not allowed to manage keys.";
        exit 1;
    fi;
    
    if isEmpty "$KEY"; then
        logError "A key must be provided";
        exit 1;
    fi;
    
    # all fine
    local CURRENTKEYS=$(cat ${BACKUPVOLUME}/.ssh/authorized_keys);
    if runCmd grep "${KEY}" "${BACKUPVOLUME}/.ssh/authorized_keys"; then
        logError "Key already added...";
        exit 1;
    fi;
    
    echo "" >> "${BACKUPVOLUME}/.ssh/authorized_keys";
    echo "# HostKey" >> "${BACKUPVOLUME}/.ssh/authorized_keys";
    echo "command=\"/usr/bin/sudo -n ${ENTRY_PATH}/sbin/ssh-client --managed --key-manager --target \\\"${BACKUPVOLUME}\\\" \${SSH_ORIGINAL_COMMAND}\" ${KEY}" >> "${BACKUPVOLUME}/.ssh/authorized_keys";
    
    logLine "Added key";
    exit 0;
}

_main "$@";
exit 0;