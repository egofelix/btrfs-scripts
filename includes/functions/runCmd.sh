#!/bin/bash
function runCmd {
  logDebug "Executing $@"

  RESULT=$($@ 2>&1)

  RESULTCODE=$?

  if [ ${RESULTCODE} -ne 0 ]; then
    logLine "Error: ${RESULT}";
	logLine "Failed Command: $@";
    return 1
  else
    return 0;
  fi;
}