#!/bin/bash
function printSendSnapshotHelp {
    echo "Usage: ${HOST_NAME} ${RECEIVER_COMMAND} [--autoremove] [--volume] [<volume>] [... <volume>]";
    echo "";
    echo "    ${HOST_NAME} ${RECEIVER_COMMAND}";
    echo "      Create snapshots of every mounted volume.";
    echo "";
    echo "    ${HOST_NAME} ${RECEIVER_COMMAND} --target /.snapshots";
    echo "      Create snapshots of every mounted volume in \"/.snapshorts\".";
    echo "";
    echo "    ${HOST_NAME} ${RECEIVER_COMMAND} --volume root-data --volume usr-data";
    echo "      Create a snapshot of volumes root-data and usr-data.";
    echo "";
    echo "If you ommit the <targetdirectory> then the script will try to locate it with the subvolume name @snapshots.";
    echo "";
}

function isSuccess {
    # Filter Output just for a line of true | false
    local CHECKRESULT=$(echo "$1" | grep -P '^true$|^false$|^yes$|^no$|^success$|^failed$|^error$')
    if [[ "${CHECKRESULT,,}" == "true" ]]; then return 0; fi;
    if [[ "${CHECKRESULT,,}" == "yes" ]]; then return 0; fi;
    if [[ "${CHECKRESULT,,}" == "success" ]]; then return 0; fi;
    
    return 1;
}

function sendSnapshotData {
    logDebug "[FUNC] Sending --volume \"${1}\" --snapshot \"${2}\" --parent \"${3:-}\"";
    logLine "Sending \"${1}/${2}\";"
    local SENDRESULT="";
    
    if [[ -z "${3:-}" ]]; then
        local CMD="btrfs send -q ${SNAPSHOTVOLUME}/${1}/${2} | ${SSH_CALL} receive-snapshot --volume "${1}" --snapshot "${2}"";
        logDebug "[MSG] Executing ${CMD}";
        SENDRESULT=$(btrfs send -q ${SNAPSHOTVOLUME}/${1}/${2} | ${SSH_CALL} receive-snapshot --volume "${1}" --snapshot "${2}");
    else
        local CMD="btrfs send -p ${SNAPSHOTVOLUME}/${1}/${3} -q ${SNAPSHOTVOLUME}/${1}/${2} | ${SSH_CALL} receive-snapshot --volume "${1}" --snapshot "${2}"";
        logDebug "[MSG] Executing ${CMD}";
        SENDRESULT=$(btrfs send -q -p ${SNAPSHOTVOLUME}/${1}/${3} ${SNAPSHOTVOLUME}/${1}/${2} | ${SSH_CALL} receive-snapshot --volume "${1}" --snapshot "${2}");
    fi;
    
    
    if [[ $? -ne 0 ]]; then
        logError "Unexpected Failed Command: \`${CMD}\` Result: ${SENDRESULT}";
        exit 1;
    fi;
    
    logSuccess "Executed \`${CMD}\` Output: \`${SENDRESULT:-}\`";
    if ! isSuccess "${SENDRESULT}"; then logWarn "Command \`${CMD}\` did not return success: \`${SENDRESULT}\`"; return 1; fi;
    
    return 0;
}

function runReceiver {
    if ! runCmd ${SSH_CALL} $@; then
        logError "SSH-Command \`$@\` failed: ${RUNCMD_CONTENT}.";
        exit 1;
    fi;
    
    # Filter Output just for a line of true | false
    if isSuccess "${RUNCMD_CONTENT}"; then return 0; fi;
    return 1;
}

function sendSnapshot {
    # Scan Arguments
    local AUTOREMOVE="false";
    local VOLUMES="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --autoremove) AUTOREMOVE="true";;
            -v|--volume) if [[ -z ${VOLUMES} ]]; then VOLUMES="$2"; else VOLUMES="${VOLUMES} $2"; fi; shift ;;
            -h|--help) printSendSnapshotHelp; exit 0;;
            *)
                if [[ -z ${VOLUMES} ]]; then
                    VOLUMES="$1";
                else
                    VOLUMES="${VOLUMES} $1";
                fi;
            ;;
        esac;
        shift;
    done;
    
    # Debug Variables
    logFunction "snapshotCommand --snapshotvolume \`${SNAPSHOTVOLUME}\` --volume \`${VOLUMES}\`";
    
    # Auto Detect SNAPSHOTVOLUME and VOLUMES
    if ! autodetect-volumes; then logError "Could not autodetect volumes"; exit 1; fi;
    if ! autodetect-snapshotvolume; then logError "Could not autodetect snapshotvolume"; exit 1; fi;
    
    # Detect Server
    if ! autodetect-server; then
        logError "snapshotCommand#Failed to detect server, please specify one with --remote <uri>";
        exit 1;
    fi;
    
    # Debug
    logFunction "createSnapshot#expandedArguments --target \`${SNAPSHOTVOLUME}\` --volume \`$(echo ${VOLUMES})\`";
    
    # Validate
    if [[ -z "${VOLUMES}" ]]; then logError "<volume> cannot be empty"; printSendSnapshotHelp; exit 1; fi;
    
    # Create Lockfile (Only one simultan instance per SNAPSHOTSPATH is allowed)
    if ! createLockFile --lockfile "${SNAPSHOTVOLUME}/.$(basename $ENTRY_SCRIPT).lock"; then
        logError "Failed to lock lockfile \"${SNAPSHOTVOLUME}/.$(basename $ENTRY_SCRIPT).lock\". Maybe another action is running already?";
        exit 1;
    fi;
    
    # Try to check if hostkey works otherwise try add it
    if ! isTrue ${SSH_IS_HOSTKEY}; then
        local HOSTKEY="";
        if [[ -f /etc/ssh/ssh_host_ed25519_key.pub ]]; then HOSTKEY=$(cat /etc/ssh/ssh_host_ed25519_key.pub); fi;
        if ! isEmpty "${HOSTKEY}"; then
            if ! runCmd ${SSH_CALL} add-hostkey --key \\\"${HOSTKEY}\\\"; then
                logWarn "Failed to local public key to remote: ${RUNCMD_CONTENT} ${HOSTKEY}";
            fi;
        fi;
    fi;
    
    logLine "Sending snapshots to ${SSH_HOSTNAME}";
    
    # Scan Volumes
    for VOLUME in ${VOLUMES}; do
        # Skip @volumes
        VOLUME=$(removeLeadingChar "${VOLUME}" "/")
        if [[ -z "${VOLUME}" ]]; then continue; fi;
        if [[ "${VOLUME}" = "@"* ]]; then logDebug "Skipping Volume ${VOLUME}"; continue; fi;
        
        # Check if there are any snapshots for this volume
        SNAPSHOTS=$(LC_ALL=C ls ${SNAPSHOTVOLUME}/${VOLUME}/)
        if [[ -z "${SNAPSHOTS}" ]]; then
            logLine "No snapshots available to transfer for volume \"${VOLUME}\".";
            continue;
        fi;
        
        #SNAPSHOTCOUNT=$(LC_ALL=C ls ${SNAPSHOTVOLUME}/${VOLUME}/ | sort | wc -l)
        FIRSTSNAPSHOT=$(LC_ALL=C ls ${SNAPSHOTVOLUME}/${VOLUME}/ | sort | head -1)
        OTHERSNAPSHOTS=$(LC_ALL=C ls ${SNAPSHOTVOLUME}/${VOLUME}/ | sort | tail -n +2) # Includes last SNAPSHOT
        LASTSNAPSHOT=$(LC_ALL=C ls ${SNAPSHOTVOLUME}/${VOLUME}/ | sort | tail -1)
        logDebug "FIRSTSNAPSHOT: ${FIRSTSNAPSHOT}";
        logDebug "LASTSNAPSHOT: ${LASTSNAPSHOT}";
        logDebug OTHERSNAPSHOTS: $(removeTrailingChar $(echo "${OTHERSNAPSHOTS}" | tr '\n' ',') ',');
        
        # Create Directory for this volume on the backup server
        #logDebug "Ensuring volume directory at server for \"${VOLUME}\"...";
        #if ! runReceiver create-volume --volume "${VOLUME}"; then exit 1; fi;
        
        # Detect which snapshots we have for this volume
        logLine "Validating volume \"${VOLUME}\".";
        if ! runCmd ${SSH_CALL} list-snapshots --volume "${VOLUME}"; then
            logError "Failed to list snapshots for volume \"${VOLUME}\".";
            exit 1;
        fi;
        local REMOTE_SNAPSHOTS="${RUNCMD_CONTENT}";
        #exit 1;
        #if ! runReceiver list-snapshots --volume "${VOLUME}"; then exit 1; fi;
        
        
        # Send FIRSTSNAPSHOT
        #if ! runReceiver check-volume-snapshot --volume "${VOLUME}" --snapshot "${FIRSTSNAPSHOT}"; then
        if [[ "${REMOTE_SNAPSHOTS}" != *"${FIRSTSNAPSHOT}"* ]]; then
            if ! sendSnapshotData "${VOLUME}" "${FIRSTSNAPSHOT}"; then exit 1; fi;
        fi;
        
        # Now loop over incremental snapshots
        PREVIOUSSNAPSHOT=${FIRSTSNAPSHOT}
        for SNAPSHOT in ${OTHERSNAPSHOTS}
        do
            #if ! runReceiver check-volume-snapshot --volume "${VOLUME}" --snapshot "${SNAPSHOT}"; then
            if [[ "${REMOTE_SNAPSHOTS}" != *"${SNAPSHOT}"* ]]; then
                if ! sendSnapshotData "${VOLUME}" "${SNAPSHOT}" "${PREVIOUSSNAPSHOT}"; then exit 1; fi;
            fi;
            
            # Remove previous subvolume as it is not needed here anymore!
            if isTrue ${AUTOREMOVE}; then
                logDebug "Removing SNAPSHOT \"${PREVIOUSSNAPSHOT}\"...";
                if ! runCmd btrfs subvolume delete "${SNAPSHOTVOLUME}/${VOLUME}/${PREVIOUSSNAPSHOT}"; then
                    logError "Failed to remove snapshot \"${SNAPSHOT}\" for volume \"${VOLUME}\": ${RUNCMD_CONTENT}.";
                    exit 1;
                fi;
            fi;
            
            # Remember this snapshot as previos so we can send the next following backup as incremental
            PREVIOUSSNAPSHOT="${SNAPSHOT}";
        done;
    done;
    
    logLine "All snapshots has been transfered";
    sync;
    exit 0;
}


sendSnapshot $@;
exit 0;