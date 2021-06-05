function autodetect-backupvolume() {
    # Scan Arguments
    logFunction "autodetect-backupvolume#Scanning Arguments";
    local ARG_BACKUPVOLUME="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --backupvolume) ARG_BACKUPVOLUME="$2"; shift;;
            *) logError "autodetect-backupvolume#Unknown Argument: $1"; return 1;;
        esac;
        shift;
    done;
    
    # Search BACKUPVOLUME via Environment or AutoDetect
    if isEmpty "${ARG_BACKUPVOLUME:-}"; then ARG_BACKUPVOLUME=$(LC_ALL=C mount | grep '@backups' | grep -o 'on /\..* type btrfs' | awk '{print $2}'); fi;
    if isEmpty "${ARG_BACKUPVOLUME}"; then logWarn "Failed to autodetect @backups directory."; return 1; fi;
    
    # Test if SNAPSHOTSPATH is a btrfs subvol
    ARG_BACKUPVOLUME=$(removeTrailingChar "${ARG_BACKUPVOLUME}" "/");
    export BACKUPVOLUME="${ARG_BACKUPVOLUME}";
    logDebug "Validating BACKUPVOLUME: ${BACKUPVOLUME}";
    #if isEmpty $(LC_ALL=C mount | grep "${BACKUPVOLUME}" | grep 'type btrfs'); then logError "<backupvolume> \"${BACKUPVOLUME}\" must be a btrfs volume"; exit 1; fi;
    
    local SUBFOLDER="";
    if [[ ! -d ${BACKUPVOLUME} ]]; then
        SUBFOLDER=$(basename ${BACKUPVOLUME});
        #echo $SUBFOLDER
        #echo ${BACKUPVOLUME};
        BACKUPVOLUME="${BACKUPVOLUME%/*}";
    fi;
    
    # Get Volumename from Path
    local TESTMOUNT=$(LC_ALL=C findmnt -n -o SOURCE --target "${BACKUPVOLUME}")
    if [[ $? -ne 0 ]] || [[ -z "${TESTMOUNT}" ]]; then logWarn "Could not verify volumename for \"${BACKUPVOLUME}\"."; return 0; fi;
    
    local TESTDEVICE=$(echo "${TESTMOUNT}" | awk -F'[' '{print $1}')
    if [[ -z "${TESTDEVICE}" ]]; then logWarn "Could not find device for ${TESTDEVICE}."; return 0; fi;
    
    local TESTVOLUME=$(echo "${TESTMOUNT}" | awk -F'[' '{print $2}' | awk -F']' '{print $1}')
    if [[ -z "${TESTVOLUME}" ]]; then logError "Could not find volume for ${TESTVOLUME}."; return 0; fi;
    
    if [[ ! ${TESTVOLUME} = "@"* ]] && [[ ! ${TESTVOLUME} = "/@"* ]]; then
        logWarn "The target directory relies on volume \"${TESTVOLUME}\" which will also be snapshotted/backuped, consider using a targetvolume with an @ name...";
    fi;
    
    if [[ -z "${SUBFOLDER}" ]]; then return 0; fi;
    
    if [[ -d "${BACKUPVOLUME}/${SUBFOLDER}" ]]; then return 0; fi;
    
    
    if runCmd mkdir "${BACKUPVOLUME}/${SUBFOLDER}"; then return 0; fi;
    
    logError "Failed to create directory \"${BACKUPVOLUME}/${SUBFOLDER}\".";
    
    
}