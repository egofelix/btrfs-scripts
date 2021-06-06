#!/bin/bash

# serverDetect [--hostname "<hostname>"] [--uri "<uri>"]
# Sets: SSH_CALL, SSH_USERNAME, SSH_HOSTNAME, SSH_PORT, SSH_IS_HOSTKEY
function autodetect-server {
    if [[ ! -z "${SSH_CALL:-}" ]]; then
        logDebug "Skipping serverDetect, using Cache...";
        return 0;
    fi;
    
    export SSH_CALL="";
    
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
        URI="ssh://${SSH_USERNAME}@${DNS_HOSTNAME}:${DNS_PORT}";
    fi;
    
    # Split SSH-URI
    if [[ ${URI} != ssh://* ]]; then
        logError "Only ssh:// protocol is supported";
        exit 1;
    fi;
    
    if [[ ${URI} = *@* ]]; then
        export SSH_USERNAME=$(echo ${URI} | cut -d'/' -f3 | cut -d'@' -f1)
        export SSH_HOSTNAME=$(echo ${URI} | cut -d'/' -f3 | cut -d'@' -f2)
    else
        if [[ -z "${HOSTNAME:-}" ]]; then HOSTNAME=$(cat /proc/sys/kernel/hostname); fi;
        MY_HOSTNAME=$(echo "${HOSTNAME}" | awk -F'.' '{print $1}')
        export SSH_USERNAME="${MY_HOSTNAME}"
        export SSH_HOSTNAME=$(echo ${URI} | cut -d'/' -f3)
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
    local SSH_TEST="ssh -o IdentityFile=/etc/ssh/ssh_host_ed25519_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -p ${SSH_PORT} ${SSH_USERNAME}@${SSH_HOSTNAME}"
    if runCmd ${SSH_TEST} "test"; then
        export SSH_IS_HOSTKEY="true";
        export SSH_CALL="ssh -o IdentityFile=/etc/ssh/ssh_host_ed25519_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -o LogLevel=QUIET -p ${SSH_PORT} ${SSH_USERNAME}@${SSH_HOSTNAME}";
    fi;
    
    # Try with AGENT
    local SSH_TEST="ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -p ${SSH_PORT} ${SSH_USERNAME}@${SSH_HOSTNAME}"
    if isEmpty ${SSH_CALL} && runCmd ${SSH_TEST} "test"; then
        export SSH_IS_HOSTKEY="false";
        export SSH_CALL="ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -o LogLevel=QUIET -p ${SSH_PORT} ${SSH_USERNAME}@${SSH_HOSTNAME}"
    fi;
    
    # Evaluate
    if isEmpty ${SSH_CALL}; then
        if [[ -z "${RUNCMD_CONTENT}" ]]; then
            logWarn "Cannot connect to ${URI}";
        else
            logWarn "Cannot connect to ${URI}: ${RUNCMD_CONTENT}";
        fi;
        
        return 1;
    fi;
    
    logSuccess "Discovered Server: ${SSH_USERNAME}@${SSH_HOSTNAME}:${SSH_PORT}";
    return 0;
}
