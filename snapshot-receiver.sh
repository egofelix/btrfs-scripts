#!/bin/bash

# serverDetect [--hostname "<hostname>"] [--uri "<uri>"]
# Sets: SSH_CALL, SSH_USERNAME, SSH_HOSTNAME, SSH_PORT
function serverDetect {
    if [[ ! -z "${SSH_CALL:-}" ]]; then
        logDebug "Skipping serverDetect, using Cache...";
        return 0;
    fi;
    
    # Scan Arguments
    logFunction "serverDetect#Scanning Arguments";
    local URI="";
    local HOSTNAME="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --uri) URI="$2"; shift;;
            --hostname) HOSTNAME="$2"; shift;;
            *) logError "serverDetect#Unknown Argument: $1"; return 1;;
        esac;
        shift;
    done;
    
    # Debug Variables
    logFunction "serverDetect --uri \"${URI}\" --hostname \"${HOSTNAME}\"";
    
    # Validate Variables
    if ! isEmpty "${URI:-}"; then
        if [[ "${URI,,}" != "ssh://"* ]]; then echo "SSH_URI must start with ssh://"; exit 1; fi;
    fi;
    
    # Try autodetect URI
    if isEmpty "${URI:-}"; then
        
        # Get hostname, if none is specified
        if [[ -z "${HOSTNAME:-}" ]]; then
            HOSTNAME=$(cat /proc/sys/kernel/hostname)
        fi;
        
        # Message for Debug-User
        logDebug "serverDetect#Trying autodetection of URI with current hostname: ${HOSTNAME}";
        
        local MY_HOSTNAME=$(echo "${HOSTNAME}" | awk -F'.' '{print $1}');
        export SSH_HOSTNAME="";
        export SSH_PORT="22";
        export SSH_USERNAME="${MY_HOSTNAME}";
        local MY_DOMAIN="";
        if [[ ${HOSTNAME} = *"."*"."* ]]; then
            MY_DOMAIN=$(echo "${HOSTNAME}" | cut -d'.' -f2-)
        fi;
        
        # If we didnt detected a domain
        if [[ -z "${MY_DOMAIN}" ]]; then
            logDebug "serverDetect#Could not detect Domain from Hostname, trying to detect Domain";
            
            # If not try to get the dns server and make a reverse lookup to it
            local DNSSERVER=$(LC_ALL=C systemd-resolve --status | grep 'Current DNS Server' | grep -o -E '[0-9\.]+')
            if [[ ! -z "${DNSSERVER}" ]]; then
                local DNS_HOSTNAME=$(dig @${DNSSERVER} -x ${DNSSERVER} +short)
                
                if [[ ! -z "${DNS_HOSTNAME}" ]]; then
                    # Split
                    MY_DOMAIN=$(echo "${DNS_HOSTNAME}" | cut -d'.' -f2-)
                    
                    # Remove trailing .
                    MY_DOMAIN="${MY_DOMAIN::-1}"
                fi;
            fi;
        fi;
        
        # Debug User Log
        logDebug "serverDetect#Detected Domain: ${MY_DOMAIN}";
        
        # Check DNS Records
        local HOST_RECORD="_${MY_HOSTNAME}._backup._ssh.${MY_DOMAIN}";
        local DOMAIN_RECORD="_backup._ssh.${MY_DOMAIN}";
        local DNS_RESULT=""
        if ! dnsResolveSrv --hostname ${HOST_RECORD}; then
            if ! dnsResolveSrv --hostname ${DOMAIN_RECORD}; then
                logLine "autodetect not possible, consider installing bind-tools";
                return 1;
            fi;
        fi;
        
        export SSH_HOSTNAME="${DNS_HOSTNAME}"
        logLine "Autodetected Backup Server: ${SSH_USERNAME}@${DNS_HOSTNAME}:${DNS_PORT}";
        export SSH_URI="ssh://${SSH_USERNAME}@${DNS_HOSTNAME}:${DNS_PORT}";
    fi;
    
    # Split SSH-URI
    if [[ ${SSH_URI} != ssh://* ]]; then
        logError "Only ssh:// protocol is supported";
        exit 1;
    fi;
    
    if [[ ${SSH_URI} = *@* ]]; then
        export SSH_USERNAME=$(echo ${SSH_URI} | cut -d'/' -f3 | cut -d'@' -f1)
        export SSH_HOSTNAME=$(echo ${SSH_URI} | cut -d'/' -f3 | cut -d'@' -f2)
    else
        if [[ -z "${HOSTNAME:-}" ]]; then HOSTNAME=$(cat /proc/sys/kernel/hostname); fi;
        MY_HOSTNAME=$(echo "${HOSTNAME}" | awk -F'.' '{print $1}')
        export SSH_USERNAME="${MY_HOSTNAME}"
        export SSH_HOSTNAME=$(echo ${SSH_URI} | cut -d'/' -f3)
    fi;
    
    if [[ ${SSH_HOSTNAME} = *:* ]]; then
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
    
    # Create directory
    RESULT=$(ls ${SNAPSHOTSPATH}/${VOLUME});
    if [[ $? -ne 0 ]]; then logError "listing snapshots of volume \"${VOLUME}\" failed: ${RESULT}."; exit 1; fi;
    echo "${RESULT}"; exit 0;
fi;

# Command upload-volume
if [[ "${COMMAND_NAME,,}" = "upload-snapshot" ]]; then
    # Test <volume> and <name> parameter
    VOLUME=$(echo "${COMMAND}" | awk '{print $2}');
    NAME=$(echo "${COMMAND}" | awk '{print $3}');
    if [[ -z "${VOLUME}" ]] || [[ -z "${NAME}" ]]; then logError "Usage: upload-snapshot <volume> <name>"; exit 1; fi;
    
    # Aquire lock
    source "${BASH_SOURCE%/*}/includes/lockfile.sh";
    
    # Check if the snapshot exists already
    if [[ -d "${SNAPSHOTSPATH}/${VOLUME}/${NAME}" ]]; then logError "already exists"; exit 1; fi;
    
    # Trap for aborted receives (cleanup)
    _failedReceive() {
        # Remove broken subvolume
        SUBVOLCHECK=$(echo "${RECEIVERESULT}" | grep -P 'At (subvol|snapshot) ' | awk '{print $3}');
        if [[ ! -z "${SUBVOLCHECK}" ]]; then
            REMOVERESULT=$(btrfs subvol del ${SNAPSHOTSPATH}/${VOLUME}/${SUBVOLCHECK});
        fi;
        
        # Exit
        logError "Receive failed."; exit 1;
    }
    trap _failedReceive EXIT SIGHUP SIGKILL SIGTERM SIGINT;
    
    # Receive
    RECEIVERESULT=$(LC_ALL=C btrfs receive ${SNAPSHOTSPATH}/${VOLUME} < /dev/stdin 2>&1);
    RESULTCODE=$?
    
    # Get name of received subvolume
    SUBVOLCHECK=$(echo "${RECEIVERESULT}" | grep -P 'At (subvol|snapshot) ' | awk '{print $3}');
    if [[ -z "${SUBVOLCHECK}" ]]; then
        # Return error
        logError "failed to detect subvolume: \"${SUBVOLCHECK}\" in \"${RECEIVERESULT}\"."; exit 1;
    fi;
    
    # Check if subvolume was received correctly
    if [[ ${RESULTCODE} -ne 0 ]]; then
        # Return error and fire trap for removal
        logError "failed to receive: ${RECEIVERESULT}."; exit 1;
    fi;
    
    if [[ "${SUBVOLCHECK}" != "${NAME}" ]]; then
        # Return error and fire trap for removal
        logError "subvolume mismatch \"${SUBVOLCHECK}\" != \"${NAME}\"."; exit 1;
    fi;
    
    # Restore Trap
    trap - EXIT SIGHUP SIGKILL SIGTERM SIGINT;
    trap _no_more_locking EXIT;
    
    # Snapshot received
    echo "success"; exit 0;
fi;

# Command download-volume
if [[ "${COMMAND_NAME,,}" = "download-snapshot" ]]; then
    # Test <volume> and <name> parameter
    VOLUME=$(echo "${COMMAND}" | awk '{print $2}');
    NAME=$(echo "${COMMAND}" | awk '{print $3}');
    if [[ -z "${VOLUME}" ]] || [[ -z "${NAME}" ]]; then logError "Usage: download-snapshot <volume> <name>"; exit 1; fi;
    
    # Check if snapshot exists
    if [[ ! -d "${SNAPSHOTSPATH}/${VOLUME}/${NAME}" ]]; then logError "snapshot does not exists"; exit 1; fi;
    
    # Aquire lock
    source "${BASH_SOURCE%/*}/includes/lockfile.sh";
    
    # Send Snapshot
    btrfs send -q ${SNAPSHOTSPATH}/${VOLUME}/${NAME};
    if [[ $? -ne 0 ]]; then logError "Error sending snapshot."; exit 1; fi;
    exit 0;
fi;

# Unknown command
logError "Unknown Command: ${COMMAND_NAME}.";
exit 1;
