#!/bin/bash
# Command create-user [-u|--username] <username>
function printCreateUserHelp {
    local MYARGS="";
    
    echo "Usage: ${HOST_NAME} ${COMMAND_VALUE} [-u|--username] <username>";
    echo "";
    echo "    ${HOST_NAME} ${COMMAND_VALUE} test";
    echo "      Create a local user test for backup usage.";
    echo "";
    echo "If you omit the <backupvolume> then the script will try to locate it with the subvolume name @backups.";
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
            *)
                if [[ -z "${USERNAME}" ]]; then
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
    if runCmd id ${USERNAME}; then logError "<username> \"${USERNAME}\" seems to already exist. Found user by id"; return 1; fi;
    local USERLINE=$(cat /etc/passwd | grep "^${USERNAME}:");
    if [[ ! -z "${USERLINE}" ]]; then logError "<username> \"${USERNAME}\" seems to already exist. Found user in /etc/passwd"; return 1; fi;
    
    # Check if group exists
    if ! runCmd getent group ssh-backup-users; then
        # Create Group
        if ! runCmd groupadd ssh-backup-users; then
            logError "Failed to create group";
            exit 1;
        fi;
        if ! runCmd getent group ssh-backup-users; then
            logError "Failed to detect group id";
            exit 1;
        fi;
    fi;
    local GID=$(echo ${RUNCMD_CONTENT} | cut -d':' -f 3);
    logDebug "Found ssh-backup-users gid: ${GID}";
    
    # check if sudoers entry exists
    if [[ ! -f "/etc/sudoers" ]]; then
        logError "Please install sudo";
        exit 1;
    fi;
    # check if sudoers allows receiver
    local CHECKLINE="%ssh-backup-users ALL=(ALL) NOPASSWD: ${ENTRY_PATH}/sbin/ssh-client";
    if ! runCmd grep "${CHECKLINE}" /etc/sudoers; then
        logDebug "adding \"${CHECKLINE}\" to /etc/sudoers";
        echo "${CHECKLINE}" >> /etc/sudoers;
        if [[ $? -ne 0 ]]; then
            logError "Failed to add sudo entry";
            exit 1;
        fi;
    fi;
    
    # Check if backup-volume has folder
    if [[ -d "${BACKUPVOLUME}/${USERNAME}" ]]; then
        logError "<username> \"${USERNAME}\" seems to already exist. Found directory \"${BACKUPVOLUME}/${USERNAME}\"";
        return 1;
    fi;
    
    # Create user
    if ! runCmd useradd --home-dir "${BACKUPVOLUME}/${USERNAME}" --create-home --groups "${GID}" "${USERNAME}"; then
        logError "Failed to add user";
        exit 1;
    fi;
    
    # Create template authorized_keys
    mkdir -p "${BACKUPVOLUME}/${USERNAME}/.ssh";
    echo "#" > "${BACKUPVOLUME}/${USERNAME}/.ssh/authorized_keys";
    echo "# Template: command=\"/usr/bin/sudo -n ${ENTRY_PATH}/sbin/ssh-client --managed --target \\\"${BACKUPVOLUME}/${USERNAME}\\\" \\\"\${SSH_ORIGINAL_COMMAND}\\\"\" SSHKEYHERE" >> "${BACKUPVOLUME}/${USERNAME}/.ssh/authorized_keys";
    echo "#" >> "${BACKUPVOLUME}/${USERNAME}/.ssh/authorized_keys";
    local LINE="";
    ssh-add -L | while read LINE; do
        echo "" >> "${BACKUPVOLUME}/${USERNAME}/.ssh/authorized_keys";
        echo "# $(echo "${LINE}" | grep -o '[^ ]\+$')" >> "${BACKUPVOLUME}/${USERNAME}/.ssh/authorized_keys";
        echo "command=\"/usr/bin/sudo -n ${ENTRY_PATH}/sbin/ssh-client --managed --key-manager --target \\\"${BACKUPVOLUME}/${USERNAME}\\\" \\\"\${SSH_ORIGINAL_COMMAND}\\\"\" ${LINE}" >> "${BACKUPVOLUME}/${USERNAME}/.ssh/authorized_keys";
    done;
    
    chown -R "${USERNAME}:" "${BACKUPVOLUME}/${USERNAME}/.ssh";
    
    # Done
    logLine "User \"${USERNAME}\" created";
}

createUser $@;
exit 0;