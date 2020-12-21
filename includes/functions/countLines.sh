#!/bin/bash
function countLines {
  if [[ -z "$@" ]]; then
    echo -n "0";
  else
    local COUNT=`echo "$@" | wc -l`;
	echo -n $COUNT;
  fi;
}