#!/bin/bash
if [[ -z ${CRYPTED:-} ]]; then
  export CRYPTED="true";
fi;

if [[ -z ${CRYPTEDPASSWORD:-} ]]; then
  export CRYPTEDPASSWORD="test1234";
fi;

if [[ -z ${SUBVOLUMES:-} ]]; then
  export SUBVOLUMES="home var srv usr opt";
fi;

if [[ -z ${DISTRO:-} ]]; then
  export DISTRO="ARCHLINUX";
fi;

if [[ -z ${VERBOSE:-} ]]; then
  export VERBOSE=" &>/dev/null";
fi;

if [[ -z ${SSH_INSECURE:-} ]]; then
  export SSH_INSECURE="false";
fi;
