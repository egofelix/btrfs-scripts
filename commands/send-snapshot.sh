#!/bin/bash
# Command send-snapshot
# /manager [-q|--quiet] [-n|--name <clienthostname>] [-s|--server ssh://user@host:port] send-snapshot [--target <targetvolume>] [-s|--snapshot <snapshot>] [--test] <volume>

function printSendSnapshotHelp {
    echo "Usage: ${ENTRY_SCRIPT} [-q|--quiet] ${ENTRY_COMMAND} [-t|--target <snapshotvolume>] [-v|--volume <volume>]";
    echo "";
    echo "    ${ENTRY_SCRIPT} ${ENTRY_COMMAND}";
    echo "      Create snapshots of every mounted volume.";
    echo "";
    echo "    ${ENTRY_SCRIPT} ${ENTRY_COMMAND} --target /.snapshots";
    echo "      Create snapshots of every mounted volume in \"/.snapshorts\".";
    echo "";
    echo "    ${ENTRY_SCRIPT} ${ENTRY_COMMAND} --volume root-data --volume usr-data";
    echo "      Create a snapshot of volumes root-data and usr-data.";
    echo "";
    echo "If you ommit the <targetdirectory> then the script will try to locate it with the subvolume name @snapshots.";
    echo "";
}

function sendSnapshot {
    # Scan Arguments
    local SNAPSHOTVOLUME="";
    local SNAPSHOT="";
    local TEST="false";
    local TESTFLAG="";
    local VOLUME="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --target) SNAPSHOTVOLUME="$2"; shift;;
            -s|--snapshot) SNAPSHOT="$2"; shift;;
            --test) TEST="true"; TESTFLAG=" --test";;
            -h|--help) echo "Print snapshot help"; exit 0;;
            -*) echo "Unknown Argument: $1"; echo "PRint help here"; exit 1;;
            *)
                if [[ -z "${VOLUME}" ]]; then
                    VOLUME="${1}";
                    if [[ -z "${VOLUME}" ]]; then logError "<volume> cannot be empty"; printSendSnapshotHelp; exit 1; fi;
                fi;
        esac;
        shift;
    done;
    
    # Debug Variables
    logFunction "snapshotCommand --target \`${SNAPSHOTVOLUME}\` --snapshot \`${SNAPSHOT}\`${TESTFLAG} ${VOLUME}";
    
    # Auto Detect SNAPSHOTVOLUME and VOLUMES
    if ! autodetect-volumes; then logError "Could not autodetect volumes"; exit 1; fi;
    if ! autodetect-snapshotvolume; then logError "Could not autodetect snapshotvolume"; exit 1; fi;
    
    # Validate
    if [[ -z "${VOLUMES}" ]]; then logError "<volume> cannot be empty"; printSendSnapshotHelp; exit 1; fi;
    
    # Debug
    logFunction "createSnapshot#expandedArguments --target \`${SNAPSHOTVOLUME}\` --volume \`$(echo ${VOLUMES})\`";
    
    # Detect Server
    if ! autodetect-server --uri "${SSH_URI:-}" --hostname ""; then
        logError "snapshotCommand#Failed to detect server, please specify one with --source <uri>";
        exit 1;
    fi;
    
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
        CREATERESULT=$(${SSH_CALL} "create-volume" "${VOLUME}");
        if [[ $? -ne 0 ]]; then logError "Command 'create-volume \"${VOLUME}\"' failed: ${CREATERESULT}."; exit 1; fi;
        
        # Send FIRSTSNAPSHOT
        CHECKVOLUMERESULT=$(${SSH_CALL} check-volume "${VOLUME}" "${FIRSTSNAPSHOT}");
        if [[ $? -ne 0 ]]; then logError "Command 'check-volume \"${VOLUME}\" \"${FIRSTSNAPSHOT}\"' failed: ${CHECKVOLUMERESULT}."; exit 1; fi;
        if isFalse ${CHECKVOLUMERESULT}; then
            logLine "Sending snapshot \"${FIRSTSNAPSHOT}\" for volume \"${VOLUME}\"... (Full)";
            SENDRESULT=$(btrfs send -q ${SNAPSHOTVOLUME}/${VOLUME}/${FIRSTSNAPSHOT} | ${SSH_CALL} upload-snapshot "${VOLUME}" "${FIRSTSNAPSHOT}");
            if [[ $? -ne 0 ]] || [[ "${SENDRESULT}" != "success" ]]; then logError "Command 'upload-snapshot \"${VOLUME}\" \"${FIRSTSNAPSHOT}\"' failed: ${SENDRESULT}"; exit 1; fi;
        fi;
        
        # Now loop over incremental snapshots
        PREVIOUSSNAPSHOT=${FIRSTSNAPSHOT}
        for SNAPSHOT in ${OTHERSNAPSHOTS}
        do
            CHECKVOLUMERESULT=$(${SSH_CALL} check-volume "${VOLUME}" "${SNAPSHOT}");
            if [[ $? -ne 0 ]]; then logError "Command 'check-volume \"${VOLUME}\" \"${SNAPSHOT}\"' failed: ${CHECKVOLUMERESULT}."; exit 1; fi;
            if isFalse ${CHECKVOLUMERESULT}; then
                logLine "Sending snapshot \"${SNAPSHOT}\" for volume \"${VOLUME}\"... (Incremental)";
                SENDRESULT=$(btrfs send -q -p ${SNAPSHOTVOLUME}/${VOLUME}/${PREVIOUSSNAPSHOT} ${SNAPSHOTVOLUME}/${VOLUME}/${SNAPSHOT} | ${SSH_CALL} upload-snapshot "${VOLUME}" "${SNAPSHOT}");
                if [[ $? -ne 0 ]] || [[ "${SENDRESULT}" != "success" ]]; then logError "Command 'upload-snapshot \"${VOLUME}\" \"${SNAPSHOT}\"' failed: ${SENDRESULT}"; exit 1; fi;
            fi;
            
            # Remove previous subvolume as it is not needed here anymore!
            logDebug "Removing SNAPSHOT \"${PREVIOUSSNAPSHOT}\"...";
            REMOVERESULT=$(btrfs subvolume delete ${SNAPSHOTVOLUME}/${VOLUME}/${PREVIOUSSNAPSHOT})
            if [[ $? -ne 0 ]]; then logError "Failed to remove snapshot \"${SNAPSHOT}\" for volume \"${VOLUME}\": ${REMOVERESULT}."; exit 1; fi;
            
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