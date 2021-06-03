function autodetect-snapshotvolume() {
    # Search SNAPSHOTSPATH via Environment or AutoDetect
    if isEmpty "${SNAPSHOTVOLUME:-}"; then export SNAPSHOTVOLUME=$(LC_ALL=C mount | grep '@snapshots' | grep -o 'on /\..* type btrfs' | awk '{print $2}'); fi;
    if isEmpty "${SNAPSHOTVOLUME}"; then logError "Cannot find @snapshots directory"; exit 1; fi;
    
    # Test if SNAPSHOTSPATH is a btrfs subvol
    logDebug "SNAPSHOTVOLUME: ${SNAPSHOTVOLUME}";
    if isEmpty $(LC_ALL=C mount | grep "${SNAPSHOTVOLUME}" | grep 'type btrfs'); then logError "<snapshotvolume> \"${SNAPSHOTVOLUME}\" must be a btrfs volume"; exit 1; fi;
    
    # Get Volumename from Path
    local SNAPSHOTMOUNT=$(LC_ALL=C findmnt -n -o SOURCE --target "${SNAPSHOTVOLUME}")
    if [[ $? -ne 0 ]] || [[ -z "${SNAPSHOTMOUNT}" ]]; then logWarn "Could not verify volumename for \"${SNAPSHOTVOLUME}\"."; return 0; fi;
    
    local SNAPSHOTMOUNTDEVICE=$(echo "${SNAPSHOTMOUNT}" | awk -F'[' '{print $1}')
    if [[ -z "${SNAPSHOTMOUNTDEVICE}" ]]; then logWarn "Could not find device for ${SNAPSHOTMOUNTDEVICE}."; return 0; fi;
    
    local SNAPSHOTMOUNTVOLUME=$(echo "${SNAPSHOTMOUNT}" | awk -F'[' '{print $2}' | awk -F']' '{print $1}')
    if [[ -z "${SNAPSHOTMOUNTVOLUME}" ]]; then logError "Could not find volume for ${SNAPSHOTMOUNTVOLUME}."; return 0; fi;
    
    if [[ ! ${SNAPSHOTMOUNTVOLUME} = "@"* ]] && [[ ! ${SNAPSHOTMOUNTVOLUME} = "/@"* ]]; then
        logWarn "The target directory relies on volume \"${SNAPSHOTMOUNTVOLUME}\" which will also be snapshotted/backupped, consider using a targetvolume with an @ name...";
    fi;
    
    return 0;
    
}