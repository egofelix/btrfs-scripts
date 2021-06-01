#!/bin/bash
function runCmd {
  logDebug "Executing $@";

  RESULT=$($@ 2>&1);

  RESULTCODE=$?;

  if [ ${RESULTCODE} -ne 0 ]; then
    logDebug "Failed Command: \`$@\` Result: ${RESULT}";
	  logLine "Failed Command: \`$@\`";
    return 1;
  else
    if [ ! -z "${RESULT}" ]; then
      logDebug "Executed \`$@\` Output: ${RESULT}";
    fi;

    return 0;
  fi;
}