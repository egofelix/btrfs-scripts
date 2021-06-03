function autodetect-volumes() {
    if isEmpty "${VOLUMES:-}"; then export VOLUMES=$(LC_ALL=C mount | grep -o -P 'subvol\=[^\s\,\)]*' | awk -F'=' '{print $2}' | sort | uniq); fi;
    if isEmpty "${VOLUMES}"; then logError "Could not detect volumes to backup"; exit 1; fi;
}