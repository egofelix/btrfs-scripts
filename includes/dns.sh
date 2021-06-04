# dnsResolveSrv --hostname "<hostname>"
# Sets: DNS_HOSTNAME, DNS_PORT
function dnsResolveSrv {
    export DNS_HOSTNAME="";
    export DNS_PORT="";
    
    # Scan Arguments
    logFunction "dnsResolveSrv#Scanning Arguments";
    local HOSTNAME="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --hostname) HOSTNAME="$2"; shift;;
            *) logError "dnsResolveSrv#Unknown Argument: $1"; return 1;;
        esac;
        shift;
    done;
    
    # Debug Variables
    logFunction "dnsResolveSrv --hostname \"${HOSTNAME}\"";
    
    # Try With nslookup
    if ! which nslookup &> /dev/null; then
        if ! runCmd nslookup -type=srv ${HOSTNAME}; then
            logDebug "Failed to lookup ${HOSTNAME}, type \"SRV\", cmd \"nslookup\"";
            return 1;
        fi;
        
        if [[ "${RUNCMD_CONTENT}" = *"NXDOMAIN"* ]]; then
            logDebug "${HOSTNAME} does not exist.";
            return 1;
        fi;
        
        local SERVICE=$(echo ${RUNCMD_CONTENT} | grep -oE '\s+service\s+\=\s+[0-9]+\s+[0-9]+\s+[0-9]+\s+[A-Za-z\.0-9]+');
        if [[ -z "${SERVICE}" ]]; then
            return 1;
        fi;
        
        DNS_PORT=$(echo ${SERVICE}  | awk '{print $5}')
        DNS_HOSTNAME=$(echo ${SERVICE}  | awk '{print $6}')
        DNS_HOSTNAME="${DNS_HOSTNAME::-1}";
        return 0;
    fi;
    
    # Try with dig
    #if ! which dig &> /dev/null; then
    #    DNS_RESULT=$(dig srv ${HOSTNAME} +short 2> /dev/null)
    #    if [[ $? -ne 0 ]]; then
    #        DNS_RESULT=""
    #        logLine "autodetect not possible, consider installing bind-tools";
    #    fi;
    #fi;
    
    return 1;
}
