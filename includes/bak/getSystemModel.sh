#!/bin/bash
function getSystemModel {
  local MODEL=$(dmesg | grep 'Machine model:' | grep -oP 'Machine\smodel\:.*' | awk -F':' '{print $2}')
  if [[ "${MODEL^^}" = *"CUBIETECH CUBIETRUCK"* ]]; then
    echo -n "CUBIETRUCK";
  else
    echo -n "UNKNOWN";
  fi;
}