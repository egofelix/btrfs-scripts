#!/bin/bash
function isTrue {
  if [[ $# -eq 0 ]]; then return 0; fi;
  if [[ "${1^^}" = "YES" ]]; then return 0; fi;
  if [[ "${1^^}" = "TRUE" ]]; then return 0; fi;
  return 1;
}
function isFalse {
  if [[ $# -eq 0 ]]; then return 0; fi;
  if [[ "${1^^}" = "NO" ]]; then return 0; fi;
  if [[ "${1^^}" = "FALSE" ]]; then return 0; fi;
  return 1;
}