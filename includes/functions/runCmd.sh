#!/bin/bash
function runCmd {
  logDebug "Executing \`$@\`";

  RESULT=$($@ 2>&1);

  RESULTCODE=$?;

  if [ ${RESULTCODE} -ne 0 ]; then
    logError "Failed Command: \`$@\` Result: ${RESULT}";
    return 1;
  else
    if [ ! -z "${RESULT}" ]; then
      logSuccess "Executed \`$@\` Output: ${RESULT}";
    else
      logSuccess "Executed \`$@\`";
    fi;

    return 0;
  fi;
}