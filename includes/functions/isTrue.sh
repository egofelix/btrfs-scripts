#!/bin/bash
function isTrue {
  if [[ "${1^^}" = "YES" ]]; then return 0; fi;
  if [[ "${1^^}" = "TRUE" ]]; then return 0; fi;
  return 1;
}