#!/bin/bash
function logLine {
  if isTrue "${QUIET:-}"; then return; fi;
  echo $@;
}