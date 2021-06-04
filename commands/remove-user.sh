#!/bin/bash
# Command create-user [-u|--username] <username>
function printRemoveUserHelp {
    echo "Usage: ${ENTRY_SCRIPT} [-q|--quiet] ${ENTRY_COMMAND} [-u|--username] <username>";
    echo "";
}
function removeUser {
    # Scan Arguments
    local USERNAME="";
    local BACKUPVOLUME="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -u|--username) USERNAME="$2"; shift;;
            -b|--backupvolume) BACKUPVOLUME="$2"; shift;;
            -h|--help) printRemoveUserHelp; exit 0;;
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
    logFunction "removeUser#arguments --username \`${USERNAME}\` --backupvolume \`${BACKUPVOLUME}\`";
    
    # Validate
    if ! autodetect-backupvolume --backupvolume "${BACKUPVOLUME}"; then logError "<backupvolume> cannot be empty"; return 1; fi;
    if isEmpty "${USERNAME}"; then logError "<username> must be provided."; return 1; fi;
    if containsIllegalCharacter "${USERNAME}"; then logError "Illegal character detected in <username> \"${USERNAME}\"."; return 1; fi;
    
    # Debug Variable
    logFunction "removeUser#expandedArguments --username \`${USERNAME}\` --backupvolume \`${BACKUPVOLUME}\`";
    
    # Check if user exists
    if ! runCmd id ${USERNAME}; then logError "<username> \"${USERNAME}\" does not seem to exist. Did not found user by id"; return 1; fi;
    local USERLINE=$(cat /etc/passwd | grep "^${USERNAME}:");
    if [[ -z "${USERLINE}" ]]; then logError "<username> \"${USERNAME}\" does not seem to exist. Did not found user in /etc/passwd"; return 1; fi;
    
    # Check if group exists
    if ! runCmd getent group ssh-backup-users; then
        logError "Failed to detect group id";
        exit 1;
    fi;
    local GID=$(echo ${RUNCMD_CONTENT} | cut -d':' -f 3);
    logDebug "Found ssh-backup-users gid: ${GID}";
    
    # Check if backup-volume has folder
    if [[ ! -d "${BACKUPVOLUME}/${USERNAME}" ]]; then logError "<username> \"${USERNAME}\" does not seem to exist. Did not found directory \"${BACKUPVOLUME}/${USERNAME}\""; return 1; fi;
    
    # Check if user is group member of ssh-backup-users
    if ! runCmd id -G "${USERNAME}"; then
        logError "Could not detect groups of user";
        exit 1;
    fi;
    if [[ "${RUNCMD_CONTENT}" != *"${GID}"* ]]; then
        logError "User \"${USERNAME}\" does not seems to be a member of group ssh-backup-users";
        exit 1;
    fi;
    
    # Remove volumes under the user
    if ! runCmd find "${BACKUPVOLUME}/${USERNAME}" -maxdepth 2 -type d ! -iname ".*" -iwholename "${BACKUPVOLUME}/${USERNAME}/*/*"; then
        logError "Failed to list contents of user";
        exit 1;
    fi;
    if [[ ! -z "${RUNCMD_CONTENT}" ]]; then
        if ! runCmd btrfs subvol del ${BACKUPVOLUME}/${USERNAME}/*/*; then
            logError "Could not clean user";
            exit 1;
        fi;
    fi;
    
    # Ok not lets delete the user
    if ! runCmd userdel -r "${USERNAME}"; then
        logError "Unable to remove the user";
        exit 1;
    fi;
    
    logLine "User has been removed";
    exit 0;
}

removeUser $@;
exit 0;