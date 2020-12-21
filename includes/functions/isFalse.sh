#!/bin/bash
function isFalse {
  if [[ "${1^^}" = "NO" ]]; then return 0; fi;
  if [[ "${1^^}" = "FALSE" ]]; then return 0; fi;
  return 1;
}