#!/bin/bash
function runCmd {
  logDebug "Executing $@";

  RESULT=$($@ 2>&1);

  RESULTCODE=$?;

  if [ ${RESULTCODE} -ne 0 ]; then
    logDebug "Failed Command: $@ Result: ${RESULT}";
	  logLine "Failed Command: $@";
    return 1;
  else
    logDebug "Executed $@ Output: ${RESULT}";
    return 0;
  fi;
}