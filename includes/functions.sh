#!/bin/bash
for f in ${BASH_SOURCE%/*}/functions/*.sh; do source $f; done