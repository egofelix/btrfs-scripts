#!/bin/bash
if [[ -z "${SSH_HOSTNAME:-}" ]]; then
  # Get info
  if [[ -z "${HOSTNAME:-}" ]]; then
    HOSTNAME=$(cat /proc/sys/kernel/hostname)
  fi;
  logDebug "Trying autodetection of SSH_HOSTNAME with current hostname: ${HOSTNAME}";  
  
  MY_HOSTNAME=$(echo "${HOSTNAME}" | awk -F'.' '{print $1}')
  export SSH_HOSTNAME=""
  export SSH_PORT="22"
  export SSH_USERNAME="${MY_HOSTNAME}"
  MY_DOMAIN=""
  if [[ ${HOSTNAME} = *"."*"."* ]]; then
    MY_DOMAIN=$(echo "${HOSTNAME}" | cut -d'.' -f2-)
  fi;
  
  # If we didnt detected a domain
  if [[ -z "${MY_DOMAIN}" ]]; then
    logDebug "Unkown Domain, trying to detect Domain";
	
    # If not try to get the dns server and make a reverse lookup to it
	DNSSERVER=$(LANG=C systemd-resolve --status | grep 'Current DNS Server' | grep -o -E '[0-9\.]+')
	
	if [[ ! -z "${DNSSERVER}" ]]; then
      DNS_HOSTNAME=$(dig @${DNSSERVER} -x ${DNSSERVER} +short)
	  
	  if [[ ! -z "${DNS_HOSTNAME}" ]]; then
	    # Split
		MY_DOMAIN=$(echo "${DNS_HOSTNAME}" | cut -d'.' -f2-)
		
		# Remove trailing .
		MY_DOMAIN="${MY_DOMAIN::-1}"
	  fi;
	fi;
  fi;
  logDebug "Detected Domain: ${MY_DOMAIN}";

  # Check DNS Records  
  
  RECORD_TO_CHECK="_${MY_HOSTNAME}._backup._ssh.${MY_DOMAIN}"
  logDebug "Looking up SRV-Record: ${RECORD_TO_CHECK}";
  DNS_RESULT=$(dig srv ${RECORD_TO_CHECK} +short)
  if [[ -z "${DNS_RESULT}" ]]; then
    RECORD_TO_CHECK="_backup._ssh.${MY_DOMAIN}"
	logDebug "Looking up SRV-Record: ${RECORD_TO_CHECK}";
    DNS_RESULT=$(dig srv ${RECORD_TO_CHECK} +short)
  fi;

  # Could not detect
  if [[ -z "${DNS_RESULT}" ]]; then
	logLine "Could not autodetect backup server. Please provide SSH_HOSTNAME or another HOSTNAME";
	exit;
  fi;

  export SSH_PORT=$(echo ${DNS_RESULT} | awk '{print $3}');
  SSH_HOSTNAME=$(echo ${DNS_RESULT} | awk '{print $4}')
  export SSH_HOSTNAME="${SSH_HOSTNAME::-1}"
  logLine "Autodetected Backup Server: ${SSH_USERNAME}@${SSH_HOSTNAME}:${SSH_PORT}";
fi;

# Test SSH
logLine "Testing ssh access: ${SSH_USERNAME}@${SSH_HOSTNAME}:${SSH_PORT}...";

# Test ssh
SSH_CALL="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -o LogLevel=QUIET -p ${SSH_PORT} ${SSH_USERNAME}@${SSH_HOSTNAME}"
TESTRESULT=$(${SSH_CALL} "testSshReceiver")
if [[ $? -ne 0 ]]; then
	logLine "SSH-Connection failed.";
	logLine "${TESTRESULT}";
	exit;
fi;