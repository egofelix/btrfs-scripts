#!/bin/bash
if [[ -z ${CRYPTED:-} ]]; then
	export CRYPTED="true";
fi;

if [[ -z ${CRYPTEDPASSWORD:-} ]]; then
	export CRYPTEDPASSWORD="test1234";
fi;

export SUBVOLUMES="home var srv usr opt";
export DISTRO="ARCHLINUX";

if [[ -z ${TIMEZONE:-} ]]; then
	export TIMEZONE="Europe/Berlin";
fi;

if [[ -z ${KEYMAP:-} ]]; then
	export KEYMAP="de";
fi;