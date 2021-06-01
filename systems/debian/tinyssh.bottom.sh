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
#EXE="$(readlink -f /sbin/dropbear)" && [ -f "$EXE" ] || exit 1

# delete authorized_keys(5) file to forbid new SSH sessions
#rm -f ~root/.ssh/authorized_keys
echo "STOP TINYSSH HERE";