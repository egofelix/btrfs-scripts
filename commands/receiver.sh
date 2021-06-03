#!/bin/bash
# Command manager
# /manager.sh [-q|--quiet] [-n|--name <clienthostname>] [-s|--server ssh://user@host:port] receiver
# Command receiver
# --username <username> <receiver-command>
function printReceiverHelp() {
    echo "TODO";
    echo "Usage: ${ENTRY_SCRIPT} [-q|--quiet] ${ENTRY_COMMAND} [-t|--target <snapshotvolume>] <receiver-command>";
    echo "";
    echo "    ${ENTRY_SCRIPT} ${ENTRY_COMMAND} --target /.backups/user test";
    echo "      Returns success if the receiver works.";
    echo "";
    
    echo "";
    echo "Possible commands are:";
    printCommandLineProxyHelp --command-path "${BASH_SOURCE}";
    exit 0;
}

function receiver() {
    # Scan Arguments
    #local SNAPSHOTVOLUME="";
    local USERNAME="";
    local RECEIVER_COMMAND="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -u|--username) USERNAME="$2"; shift;;
            -h|--help) printReceiverHelp; exit 0;;
            -*) logError "Unknown Argument: $1"; printReceiverHelp; exit 1;;
            *) RECEIVER_COMMAND="${1}"; shift; break;;
        esac;
        shift;
    done;
    
    # Debug Variables
    logFunction "receiver#arguments --username \`${USERNAME}\` \`${RECEIVER_COMMAND}\`";
    
    # Validate
    if [[ -z "${RECEIVER_COMMAND}" ]]; then
        logError "No command specified";
        printReceiverHelp;
        exit 1;
    fi;
    
    if [[ -z "${USERNAME}" ]]; then logError "<username> cannot be empty"; exit 1; fi;
    if containsIllegalCharacter "${USERNAME}"; then logError "Illegal character detected in <username> \"${USERNAME}\"."; return 1; fi;
    
    # Proxy
    if ! commandLineProxy --command-name "receiver-command" --command-value "${RECEIVER_COMMAND:-}" --command-path "${BASH_SOURCE}" $@; then printReceiverHelp; exit 1; fi;
    exit 0;
    
    # Command check-volume
    if [[ "${COMMAND_NAME,,}" = "check-volume" ]]; then
        # Test <volume> and <name> parameter
        VOLUME=$(LC_ALL=C echo "${COMMAND}" | awk '{print $2}');
        NAME=$(LC_ALL=C echo "${COMMAND}" | awk '{print $3}');
        if [[ -z "${VOLUME}" ]] || [[ -z "${NAME}" ]]; then logError "Usage: check-volume <volume> <name>"; exit 1; fi;
        
        # Test and return
        if [[ ! -d "${SNAPSHOTSPATH}/${VOLUME}/${NAME}" ]]; then echo "false"; exit 0; fi;
        echo "true"; exit 0;
    fi;
    
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
    
    # Command upload-volume
    if [[ "${COMMAND_NAME,,}" = "upload-snapshot" ]]; then
        # Test <volume> and <name> parameter
        VOLUME=$(echo "${COMMAND}" | awk '{print $2}');
        NAME=$(echo "${COMMAND}" | awk '{print $3}');
        if [[ -z "${VOLUME}" ]] || [[ -z "${NAME}" ]]; then logError "Usage: upload-snapshot <volume> <name>"; exit 1; fi;
        
        # Aquire lock
        source "${BASH_SOURCE%/*}/includes/lockfile.sh";
        
        # Check if the snapshot exists already
        if [[ -d "${SNAPSHOTSPATH}/${VOLUME}/${NAME}" ]]; then logError "already exists"; exit 1; fi;
        
        # Trap for aborted receives (cleanup)
        _failedReceive() {
            # Remove broken subvolume
            SUBVOLCHECK=$(echo "${RECEIVERESULT}" | grep -P 'At (subvol|snapshot) ' | awk '{print $3}');
            if [[ ! -z "${SUBVOLCHECK}" ]]; then
                REMOVERESULT=$(btrfs subvol del ${SNAPSHOTSPATH}/${VOLUME}/${SUBVOLCHECK});
            fi;
            
            # Exit
            logError "Receive failed."; exit 1;
        }
        trap _failedReceive EXIT SIGHUP SIGKILL SIGTERM SIGINT;
        
        # Receive
        RECEIVERESULT=$(LC_ALL=C btrfs receive ${SNAPSHOTSPATH}/${VOLUME} < /dev/stdin 2>&1);
        RESULTCODE=$?
        
        # Get name of received subvolume
        SUBVOLCHECK=$(echo "${RECEIVERESULT}" | grep -P 'At (subvol|snapshot) ' | awk '{print $3}');
        if [[ -z "${SUBVOLCHECK}" ]]; then
            # Return error
            logError "failed to detect subvolume: \"${SUBVOLCHECK}\" in \"${RECEIVERESULT}\"."; exit 1;
        fi;
        
        # Check if subvolume was received correctly
        if [[ ${RESULTCODE} -ne 0 ]]; then
            # Return error and fire trap for removal
            logError "failed to receive: ${RECEIVERESULT}."; exit 1;
        fi;
        
        if [[ "${SUBVOLCHECK}" != "${NAME}" ]]; then
            # Return error and fire trap for removal
            logError "subvolume mismatch \"${SUBVOLCHECK}\" != \"${NAME}\"."; exit 1;
        fi;
        
        # Restore Trap
        trap - EXIT SIGHUP SIGKILL SIGTERM SIGINT;
        trap _no_more_locking EXIT;
        
        # Snapshot received
        echo "success"; exit 0;
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