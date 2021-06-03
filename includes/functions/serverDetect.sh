# Command manager
# /manager.sh [-q|--quiet] [-n|--name <clienthostname>] [-s|--server ssh://user@host:port] create-snapshot
# Command create-snapshot
# [-v|--volume <volume>] [-t|--target <snapshotvolume>]
function printCreateSnapshotHelp {
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
function createSnapshot {
    # Scan Arguments
    local SNAPSHOTVOLUME="";
    local VOLUMES="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -t|--target) SNAPSHOTVOLUME="$2"; shift;;
            -v|--volume) if [[ -z ${VOLUMES} ]]; then VOLUMES="$2"; else VOLUMES="${VOLUMES} $2"; fi; shift ;;
            #-v|--volume) VOLUMES="$2"; shift;;
            -h|--help) printCreateSnapshotHelp; exit 0;;
            *) logError "Unknown Argument: $1"; exit 1;;
        esac;
        shift;
    done;
    
    # Debug Variables
    logFunction "createSnapshot#arguments --target \`${SNAPSHOTVOLUME}\` --volume \`${VOLUMES}\`";
    
    # Lockfile (Only one simultan instance is allowed)
    stopIfNotElevated;
    loadFunction "createLockFile"
    if ! createLockFile; then logError "Failed to lock lockfile. Maybe another action is running already?"; exit 1; fi;
    logDebug "Lock-File created";
    
    # Auto Detect SNAPSHOTVOLUME and VOLUMES
    loadFunction autodetect-snapshotvolume autodetect-volumes;
    autodetect-snapshotvolume;
    autodetect-volumes;
    
    # Debug
    logFunction "createSnapshot#expandedArguments --target \`${SNAPSHOTVOLUME}\` --volume \`$(echo ${VOLUMES})\`";
    
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
exit 0;    if [[ ${SSH_HOSTNAME} = *:* ]]; then
        export SSH_PORT=$(echo ${SSH_HOSTNAME} | cut -d':' -f2)
        export SSH_HOSTNAME=$(echo ${SSH_HOSTNAME} | cut -d':' -f1)
    else
        export SSH_PORT="22"
    fi;
    
    
    # Test SSH
    logDebug "Testing ssh access: ${SSH_USERNAME}@${SSH_HOSTNAME}:${SSH_PORT}...";
    
    # Try with local key
    if isTrue ${SSH_ACCEPT_NEW_HOSTKEY:-}; then
        export SSH_CALL="ssh -o IdentityFile=/etc/ssh/ssh_host_ed25519_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -o LogLevel=QUIET -p ${SSH_PORT} ${SSH_USERNAME}@${SSH_HOSTNAME}"
    else
        export SSH_CALL="ssh -o IdentityFile=/etc/ssh/ssh_host_ed25519_key -o IdentitiesOnly=yes -o VerifyHostKeyDNS=yes -o ConnectTimeout=8 -o LogLevel=QUIET -p ${SSH_PORT} ${SSH_USERNAME}@${SSH_HOSTNAME}"
    fi;
    local TESTRESULT=$(${SSH_CALL} "testReceiver")
    if [[ $? -ne 0 ]]; then
        # Test ssh without key (User auth)
        if isTrue ${SSH_INSECURE}; then
            export SSH_CALL="ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -o LogLevel=QUIET -p ${SSH_PORT} ${SSH_USERNAME}@${SSH_HOSTNAME}"
        else
            export SSH_CALL="ssh -o PasswordAuthentication=no -o VerifyHostKeyDNS=yes -o ConnectTimeout=8 -o LogLevel=QUIET -p ${SSH_PORT} ${SSH_USERNAME}@${SSH_HOSTNAME}"
        fi;
        TESTRESULT=$(${SSH_CALL} "testReceiver")
        if [[ $? -ne 0 ]]; then
            logError "Cannot connect to ${SSH_URI}";
            exit 1;
        fi;
    fi;
    
    logSuccess "Discovered Server: ${SSH_USERNAME}@${SSH_HOSTNAME}:${SSH_PORT}";
}
