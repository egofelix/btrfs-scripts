#!/bin/bash
if [[ -z "${SSH_HOSTNAME:-}" ]]; then
  export SSH_HOSTNAME=""
  export SSH_PORT="22"
  export SSH_USERNAME=$(cat /proc/sys/kernel/hostname | awk -F'.' '{print $1}')
  
  # Get info
  if [[ -z "${HOSTNAME:-}" ]]; then
    HOSTNAME=$(cat /proc/sys/kernel/hostname)
  fi;
  MY_HOSTNAME=$(echo "${HOSTNAME}" | awk -F'.' '{print $1}')
  MY_DOMAIN=$(cat /proc/sys/kernel/hostname | cut -d'.' -f2-)
  
  # If we didnt detected a domain
  if [[ -z ${MY_DOMAIN} ]]; then
    # If not try to get the dns server and make a reverse lookup to it
	DNSSERVER=$(LANG=C systemd-resolve --status | grep 'Current DNS Server' | grep -o -E '[0-9\.]+')
	
	if [[ ! -z "${DNSSERVER}" ]]; then
      DNS_HOSTNAME=$(dig @${DNSSERVER} -x ${DNSSERVER} +short)
	  
	  if [[ ! -z "${DNS_HOSTNAME}" ]]; then
		MY_DOMAIN=$(echo "${DNS_HOSTNAME}" | cut -d'.' -f2-)
	  fi;
	fi;
  fi;

  # Check DNS Records  
  RECORD_TO_CHECK="_${MY_HOSTNAME}._backup._ssh.${MY_DOMAIN}"
  DNS_RESULT=$(dig srv ${RECORD_TO_CHECK} +short)
  if [[ -z "${DNS_RESULT}" ]]; then
    RECORD_TO_CHECK="_backup._ssh.${MY_DOMAIN}"
    DNS_RESULT=$(dig srv ${RECORD_TO_CHECK} +short)
  fi;

  # Could not detect
  if [[ -z "${DNS_RESULT}" ]]; then
	logLine "Could not autodetect backup server. Please provide SNAPTARGET";
	exit;
  fi;

  export SSH_PORT=$(echo ${DNS_RESULT} | awk '{print $3}');
  SSH_HOSTNAME=$(echo ${DNS_RESULT} | awk '{print $4}')
  export SSH_HOSTNAME="${SSH_HOSTNAME::-1}"
  logLine "Autodetected Backup Server: ${DNS_RESULT}";
fi;