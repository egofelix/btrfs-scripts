#!/bin/bash
function printCreateSnapshotHelp {
    local MYARGS="[-t|--target <snapshotvolume>] [-v|--volume] <volume>";
    local ARGS=${ENTRY_ARGS};
    ARGS="${ARGS/\<command\>/${ENTRY_COMMAND}}";
    ARGS="${ARGS/\[\<commandargs\>\]/${MYARGS}}";
    echo "Usage: ${ENTRY_SCRIPT} ${ARGS}";
    echo "";
    echo "    ${ENTRY_SCRIPT} ${ENTRY_COMMAND}";
    echo "      Create snapshots of every mounted volume.";
    echo "";
    echo "    ${ENTRY_SCRIPT} ${ENTRY_COMMAND} --target /.snapshots";
    echo "      Create snapshots of every mounted volume in \"/.snapshorts\".";
    echo "";
    echo "    ${ENTRY_SCRIPT} ${ENTRY_COMMAND} --target /.snapshots root-data usr-data";
    echo "      Create a snapshot of volumes root-data and usr-data in \"/.snapshorts\".";
    echo "";
    echo "    ${ENTRY_SCRIPT} ${ENTRY_COMMAND} root-data usr-data";
    echo "      Create a snapshot of volumes root-data and usr-data.";
    echo "";
    echo "    ${ENTRY_SCRIPT} ${ENTRY_COMMAND} -v root-data --volume usr-data";
    echo "      Create a snapshot of volumes root-data and usr-data.";
    echo "";
    echo "If you omit the <snapshotvolume> then the script will try to locate it with the subvolume name @snapshots.";
    echo "";
}

# create-snapshot [-t|--target <snapshotvolume>] [-v|--volume] <volume> (... <volume>)
function createSnapshot {
    # Scan Arguments
    local SNAPSHOTVOLUME="";
    local VOLUMES="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -t|--target) SNAPSHOTVOLUME="$2"; shift;;
            -v|--volume) if [[ -z ${VOLUMES} ]]; then VOLUMES="$2"; else VOLUMES="${VOLUMES} $2"; fi; shift ;;
            -h|--help) printCreateSnapshotHelp; exit 0;;
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
    logFunction "createSnapshot#arguments --target \`${SNAPSHOTVOLUME}\` --volume \`${VOLUMES}\`";
    
    # Validate
    autodetect-snapshotvolume;
    autodetect-volumes;
    
    # Debug
    logFunction "createSnapshot#expandedArguments --target \`${SNAPSHOTVOLUME}\` --volume \`$(echo ${VOLUMES})\`";
    
    # Create Lockfile (Only one simultan instance per SNAPSHOTSPATH is allowed)
    #if ! createLockFile --lockfile "${SNAPSHOTVOLUME}/.$(basename $ENTRY_SCRIPT).lock"; then
    #    logError "Failed to lock lockfile \"${SNAPSHOTVOLUME}/.$(basename $ENTRY_SCRIPT).lock\". Maybe another action is running already?";
    #    exit 1;
    #fi;
    #logDebug "Lock-File created";
    
    # Test if VOLUMES are btrfs subvol's
    local VOLUME;
    for VOLUME in ${VOLUMES}
    do
        VOLUME=$(removeLeadingChar "${VOLUME}" "/");
        if [[ -z "${VOLUME}" ]]; then continue; fi;
        if [[ "${VOLUME}" = "@"* ]]; then continue; fi;
        
        logDebug "Testing btrfs on VOLUME: ${VOLUME}";
        if isEmpty $(LC_ALL=C mount | grep -P "[\(\,](subvol\=[/]{0,1}${VOLUME})[\)\,]" | grep 'type btrfs'); then logError "Source \"${VOLUME}\" could not be found."; exit 1; fi;
    done;
    
    # Current time
    local STAMP=$(date -u +"%Y-%m-%d_%H-%M-%S");
    
    # Backup
    logLine "Target Directory: ${SNAPSHOTVOLUME}";
    for VOLUME in ${VOLUMES}
    do
        VOLUME=$(removeLeadingChar "${VOLUME}" "/");
        if [[ -z "${VOLUME}" ]]; then continue; fi;
        if [[ "${VOLUME}" = "@"* ]]; then logDebug "Skipping Volume ${VOLUME}"; continue; fi;
        
        # Find the first mountpoint for the volume
        VOLUMEMOUNTPOINT=$(LC_ALL=C mount | grep -P "[\(\,](subvol\=[/]{0,1}${VOLUME})[\)\,]" | grep -o -P 'on(\s)+[^\s]*' | awk '{print $2}' | head -1);
        
        # Create Directory for this volume
        if [[ ! -d "${SNAPSHOTVOLUME}/${VOLUME}" ]]; then
            if ! runCmd mkdir -p ${SNAPSHOTVOLUME}/${VOLUME}; then logError "Failed to create directory ${SNAPSHOTVOLUME}/${VOLUME}."; exit 1; fi;
        fi;
        
        # Create Snapshot
        if [[ -d "${SNAPSHOTVOLUME}/${VOLUME}/${STAMP}" ]]; then
            logLine "Snapshot already exists. Aborting";
        else
            logLine "Creating Snapshot ${SNAPSHOTVOLUME}/${VOLUME}/${STAMP}";
            if ! runCmd btrfs subvolume snapshot -r ${VOLUMEMOUNTPOINT} ${SNAPSHOTVOLUME}/${VOLUME}/${STAMP}; then
                logError "Failed to create snapshot of ${SNAPSHOTVOLUME}/${VOLUME}/${STAMP}";
                exit 1;
            fi;
            logVerbose "Created Snapshot ${SNAPSHOTVOLUME}/${VOLUME}/${STAMP}";
        fi;
    done;
    
    # Finish
    sync;
    logLine "Snapshots done.";
}

createSnapshot $@;
exit 0;