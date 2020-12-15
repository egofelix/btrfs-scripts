#!/bin/bash
if [[ -z ${CRYPTED:-} ]]; then
	export CRYPTED="true";
fi;

if [[ -z ${CRYPTEDPASSWORD:-} ]]; then
	export CRYPTEDPASSWORD="test1234";
fi;

export SUBVOLUMES="home var";
export DISTRO="ARCHLINUX";