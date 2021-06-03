function autodetect-snapshotvolume() {
    # Search SNAPSHOTSPATH via Environment or AutoDetect
    if isEmpty "${SNAPSHOTVOLUME:-}"; then export SNAPSHOTVOLUME=$(LC_ALL=C mount | grep '@snapshots' | grep -o 'on /\..* type btrfs' | awk '{print $2}'); fi;
    if isEmpty "${SNAPSHOTVOLUME}"; then logError "Cannot find @snapshots directory"; exit 1; fi;
    
    # Test if SNAPSHOTSPATH is a btrfs subvol
    logDebug "SNAPSHOTVOLUME: ${SNAPSHOTVOLUME}";
    if isEmpty $(LC_ALL=C mount | grep "${SNAPSHOTVOLUME}" | grep 'type btrfs'); then logError "<snapshotvolume> \"${SNAPSHOTVOLUME}\" must be a btrfs volume"; exit 1; fi;
    
}