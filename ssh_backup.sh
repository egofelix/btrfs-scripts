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
exit 0;	logDebug "LASTSNAPSHOT: ${LASTSNAPSHOT}";
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
	  SENDRESULT=$(btrfs send -q ${SNAPSHOTSPATH}/${VOLUME}/${FIRSTSNAPSHOT} | ${SSH_CALL} upload-snapshot "${VOLUME}" "${FIRSTSNAPSHOT}");
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
	    SENDRESULT=$(btrfs send -q -p ${SNAPSHOTSPATH}/${VOLUME}/${PREVIOUSSNAPSHOT} ${SNAPSHOTSPATH}/${VOLUME}/${SNAPSHOT} | ${SSH_CALL} upload-snapshot "${VOLUME}" "${SNAPSHOT}");
	    if [[ $? -ne 0 ]] || [[ "${SENDRESULT}" != "success" ]]; then logError "Command 'upload-snapshot \"${VOLUME}\" \"${SNAPSHOT}\"' failed: ${SENDRESULT}"; exit 1; fi;
	  fi;

	  # Remove previous subvolume as it is not needed here anymore!	  
	  logDebug "Removing SNAPSHOT \"${PREVIOUSSNAPSHOT}\"...";
	  REMOVERESULT=$(btrfs subvolume delete ${SNAPSHOTSPATH}/${VOLUME}/${PREVIOUSSNAPSHOT})
	  if [[ $? -ne 0 ]]; then logError "Failed to remove snapshot \"${SNAPSHOT}\" for volume \"${VOLUME}\": ${REMOVERESULT}."; exit 1; fi;
	  
	  # Remember this snapshot as previos so we can send the next following backup as incremental
	  PREVIOUSSNAPSHOT="${SNAPSHOT}";
    done;
  done;
	
  logLine "All snapshots has been transfered";
  sync;
  exit 0;
fi;
if [[ "${COMMAND,,}" = "check-latest" ]]; then
  for VOLUME in ${VOLUMES}; do
    logDebug "Checking volume: ${VOLUME}...";
    CHECKRESULT=$(${SSH_CALL} "list-snapshots" "${VOLUME}" | sort | tail -1)
	if [[ $? -ne 0 ]]; then logError "Could not check-volume \"${VOLUME}\": ${CHECKRESULT}."; exit 1; fi;
	echo "${VOLUME}: ${CHECKRESULT}";
  done

  exit 0;  
fi;

logError "Unknown command \"${COMMAND}\"";
exit 1;