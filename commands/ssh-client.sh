#!/bin/bash
# Command manager
# /manager.sh [-q|--quiet] [-n|--name <clienthostname>] [-s|--server ssh://user@host:port] receiver
# Command receiver
# --username <username> <receiver-command>
function printReceiverHelp() {
    echo "TODO";
    echo "Usage: ${ENTRY_SCRIPT} [-q|--quiet] ${ENTRY_COMMAND} -t|--target <backupvolume> <receiver-command>";
    echo "";
    echo "    ${ENTRY_SCRIPT} ${ENTRY_COMMAND} --target /.backups/user test";
    echo "      Returns success if the receiver works.";
    echo "";
    
    echo "";
    echo "Possible commands are:";
    printCommandLineProxyHelp --command-path "${BASH_SOURCE}";
}

function receiver() {
    #local LOGFILE="/tmp/receiver.log";
    
    # Scan Arguments
    #local SNAPSHOTVOLUME="";
    #local USERNAME="";
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
    if isEmpty ${BACKUPVOLUME}; then logError "<backupvolume> cannot be empty"; exit 1; fi;
    if ! autodetect-backupvolume --backupvolume "${BACKUPVOLUME}"; then logError "<backupvolume> cannot be empty"; exit 1; fi;
    #if [[ -z "${USERNAME}" ]]; then logError "<username> cannot be empty"; exit 1; fi;
    #if containsIllegalCharacter "${USERNAME}"; then logError "Illegal character detected in <username> \"${USERNAME}\"."; return 1; fi;
    
    # Proxy
    if ! commandLineProxy --command-name "receiver-command" --command-value "${RECEIVER_COMMAND:-}" --command-path "${BASH_SOURCE}" $@; then printReceiverHelp; exit 1; fi;
    exit 0;
    
    # Command list-volumes
    if [[ "${COMMAND_NAME,,}" = "list-volumes" ]]; then
        # list directory
        RESULT=$(LC_ALL=C ls ${SNAPSHOTSPATH})
        if [[ $? -ne 0 ]]; then logError "listing volumes failed: ${RESULT}."; exit 1; fi;
        echo "${RESULT}"; exit 0;
    fi;
    
    # Command list-volume
    if [[ "${COMMAND_NAME,,}" = "list-snapshots" ]]; then
        # Test <volume> parameter
        VOLUME=$(LC_ALL=C echo "${COMMAND}" | awk '{print $2}')
        if [[ -z "${VOLUME}" ]]; then logError "Usage: list-snapshots <volume>"; exit 1; fi;
        
        # Create directory
        RESULT=$(LC_ALL=C ls ${SNAPSHOTSPATH}/${VOLUME});
        if [[ $? -ne 0 ]]; then logError "listing snapshots of volume \"${VOLUME}\" failed: ${RESULT}."; exit 1; fi;
        echo "${RESULT}"; exit 0;
    fi;
    
    # Command download-volume
    if [[ "${COMMAND_NAME,,}" = "download-snapshot" ]]; then
        # Test <volume> and <name> parameter
        VOLUME=$(echo "${COMMAND}" | awk '{print $2}');
        NAME=$(echo "${COMMAND}" | awk '{print $3}');
        if [[ -z "${VOLUME}" ]] || [[ -z "${NAME}" ]]; then logError "Usage: download-snapshot <volume> <name>"; exit 1; fi;
        
        # Check if snapshot exists
        if [[ ! -d "${SNAPSHOTSPATH}/${VOLUME}/${NAME}" ]]; then logError "snapshot does not exists"; exit 1; fi;
        
        # Aquire lock
        source "${BASH_SOURCE%/*}/includes/lockfile.sh";
        
        # Send Snapshot
        btrfs send -q ${SNAPSHOTSPATH}/${VOLUME}/${NAME};
        if [[ $? -ne 0 ]]; then logError "Error sending snapshot."; exit 1; fi;
        exit 0;
    fi;
    
    # Unknown command
    logError "Unknown Command: ${COMMAND_NAME}.";
    exit 1;
}

receiver $@;
exit 0;