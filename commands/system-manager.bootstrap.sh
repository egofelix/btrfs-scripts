#!/bin/bash
function printHelp {
    echo "Usage: ${ENTRY_SCRIPT} [-q|--quiet] ${ENTRY_COMMAND} [--snapshotvolume <snapshotvolume>] [--server ssh://user@host:port] [--volume <volume>]";
}

function sendSnapshot {
    # Scan Arguments
    local SNAPSHOTVOLUME="";
    local SNAPSHOT="";
    local SERVER="";
    local AUTOREMOVE="false";
    #local TEST="false";
    #local TESTFLAG="";
    local VOLUMES="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --snapshotvolume) SNAPSHOTVOLUME="$2"; shift;;
            --autoremove) AUTOREMOVE="true";;
            --server) SERVER="$2"; shift;;
            --volume)
                # Todo, make useable multiple times
            VOLUMES="$2"; shift;;
            -h|--help) printSendSnapshotHelp; exit 0;;
            -*) logError "Unknown Argument: $1"; printSendSnapshotHelp; exit 1;;
            *)
                if [[ -z "${VOLUME}" ]]; then
                    VOLUME="${1}";
                    if [[ -z "${VOLUME}" ]]; then logError "<volume> cannot be empty"; printSendSnapshotHelp; exit 1; fi;
                fi;
        esac;
        shift;
    done;
    
    # Debug Variables
    logFunction "snapshotCommand --snapshotvolume \`${SNAPSHOTVOLUME}\` --server \`${SERVER}\` --volume \`${VOLUMES}\`";
    
    # Auto Detect SNAPSHOTVOLUME and VOLUMES
    if ! autodetect-volumes; then logError "Could not autodetect volumes"; exit 1; fi;
    if ! autodetect-snapshotvolume; then logError "Could not autodetect snapshotvolume"; exit 1; fi;
    
    # Detect Server
    if ! autodetect-server --uri "${SERVER}" --hostname ""; then
        logError "snapshotCommand#Failed to detect server, please specify one with --source <uri>";
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
        logDebug "Ensuring volume directory at server for \"${VOLUME}\"...";
        if ! runReceiver create-volume --volume "${VOLUME}"; then exit 1; fi;
        
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