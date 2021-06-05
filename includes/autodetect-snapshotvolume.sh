function autodetect-snapshotvolume() {
    if [[ ! -z "${SNAPSHOTVOLUME:-}" ]]; then
        logDebug "Skipping autodetect-snapshotvolume, using Cache...";
        return 0;
    fi;
    
    # Search SNAPSHOTSPATH via Environment or AutoDetect
    if isEmpty "${SNAPSHOTVOLUME:-}"; then export SNAPSHOTVOLUME=$(LC_ALL=C mount | grep '@snapshots' | grep -o 'on /\..* type btrfs' | awk '{print $2}'); fi;
    if isEmpty "${SNAPSHOTVOLUME}"; then logError "Cannot find @snapshots directory"; return 1; fi;
    
    # Test if SNAPSHOTSPATH is a btrfs subvol
    logDebug "SNAPSHOTVOLUME: ${SNAPSHOTVOLUME}";
    if isEmpty $(LC_ALL=C mount | grep "${SNAPSHOTVOLUME}" | grep 'type btrfs'); then logError "<snapshotvolume> \"${SNAPSHOTVOLUME}\" must be a btrfs volume"; exit 1; fi;
    
    # Get Volumename from Path
    local TESTMOUNT=$(LC_ALL=C findmnt -n -o SOURCE --target "${SNAPSHOTVOLUME}")
    if [[ $? -ne 0 ]] || [[ -z "${TESTMOUNT}" ]]; then logWarn "Could not verify volumename for \"${SNAPSHOTVOLUME}\"."; return 1; fi;
    
    local TESTDEVICE=$(echo "${TESTMOUNT}" | awk -F'[' '{print $1}')
    if [[ -z "${TESTDEVICE}" ]]; then logWarn "Could not find device for ${TESTDEVICE}."; return 1; fi;
    
    local TESTVOLUME=$(echo "${TESTMOUNT}" | awk -F'[' '{print $2}' | awk -F']' '{print $1}')
    if [[ -z "${TESTVOLUME}" ]]; then logError "Could not find volume for ${TESTVOLUME}."; return 1; fi;
    
    if [[ ! ${TESTVOLUME} = "@"* ]] && [[ ! ${TESTVOLUME} = "/@"* ]]; then
        logWarn "The target directory relies on volume \"${TESTVOLUME}\" which will also be snapshotted/backupped, consider using a targetvolume with an @ name...";
    fi;
    
    return 0;
    
}