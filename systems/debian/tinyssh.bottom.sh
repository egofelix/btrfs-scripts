#!/bin/sh

PREREQ=""

prereqs() {
        echo "$PREREQ"
}

case "$1" in
        prereqs)
                prereqs
                exit 0
        ;;
esac

. /scripts/functions

/bin/killall tcpsvd
/bin/killall tinysshd