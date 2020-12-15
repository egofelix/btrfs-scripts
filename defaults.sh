#!/bin/bash
if [[ -z ${CRYPTED:-} ]]; then
	export CRYPTED="true";
fi;

export SUBVOLUMES="home var usr";