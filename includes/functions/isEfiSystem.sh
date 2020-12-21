#!/bin/bash
function isEfiSystem {
 if [[ ! -d "/sys/firmware/efi" ]]; then
    return 1;
  else
    return 0;
  fi;
}
