#!/bin/bash
# Command create-user [-u|--username] <username>
function printCreateUserHelp {
    echo "Usage: ${ENTRY_SCRIPT} [-q|--quiet] ${ENTRY_COMMAND} [-u|--username] <username>";
    echo "";
}
function createUser {
    # Scan Arguments
    local USERNAME="";
    local BACKUPVOLUME="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -u|--username) USERNAME="$2"; shift;;
            -b|--backupvolume) BACKUPVOLUME="$2"; shift;;
            -h|--help) printCreateUserHelp; exit 0;;
            *) if [[ -z "${USERNAME}" ]]; then
                    USERNAME="${1}";
                    if [[ -z "${USERNAME}" ]]; then
                        logError "<username> cannot be empty";
                        exit 1;
                    fi;
                else
                    logError "Unknown Argument: $1"; exit 1;
                fi;
            ;;
        esac;
        shift;
    done;
    
    # Debug Variables
    USERNAME="${USERNAME,,}";
    logFunction "createUser#arguments --username \`${USERNAME}\` --backupvolume \`${BACKUPVOLUME}\`";
    
    # Validate
    if ! autodetect-backupvolume --backupvolume "${BACKUPVOLUME}"; then logError "<backupvolume> cannot be empty"; exit 1; fi;
    if isEmpty "${USERNAME}"; then logError "<username> must be provided."; return 1; fi;
    if containsIllegalCharacter "${USERNAME}"; then logError "Illegal character detected in <username> \"${USERNAME}\"."; return 1; fi;
    
    # Debug Variable
    logFunction "createUser#expandedArguments --username \`${USERNAME}\` --backupvolume \`${BACKUPVOLUME}\`";
    
    # Check if user exists
    if runCmd id ${USERNAME}; then logError "<username> \"${USERNAME}\" seems to already exist"; return 1; fi;
    local USERLINE=$(cat /etc/passwd | grep "^${USERNAME}:");
    if [[ ! -z "${USERLINE}" ]]; then logError "<username> \"${USERNAME}\" seems to already exist"; return 1; fi;
    
    # Check if backup-volume has folder
    
    
}

createUser $@;
exit 0;