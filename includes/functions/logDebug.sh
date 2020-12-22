#!/bin/bash
function logDebug {
  if isTrue "${DEBUG:-}"; then
    echo $@;
  fi;
}