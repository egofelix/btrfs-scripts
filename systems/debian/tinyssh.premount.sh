#!/bin/sh

PREREQ="udev"

prereqs() {
    echo "$PREREQ"
}

case "$1" in
    prereqs)
        prereqs
        exit 0
    ;;
esac

[ "$IP" != off -a "$IP" != none -a -x /sbin/tinysshd ] || exit 0


run_tinyssh() {
    local flags="l"
    local ssh_port=22
    [ "$debug" != y ] || flags="Lv" # log to standard error

    ssh_port=${TINYSSH_PORT:-$ssh_port}

    # always run configure_networking() before tinysshd(8); on NFS
    # mounts this has been done already
    [ "$BOOT" = nfs ] || configure_networking

    log_begin_msg "Starting tinysshd"
    # using exec and keeping tinyssh in the foreground enables the
    # init-bottom script to kill the remaining ipconfig processes if
    # someone unlocks the rootfs from the console while the network is
    # being configured
    #exec /bin/nc -ll -p $ssh_port -e /usr/sbin/tinysshd -$flags ${TINYSSH_OPTIONS-} /etc/tinyssh/sshkeydir
    exec /bin/tcpsvd -l localhost 0 22 /usr/sbin/tinysshd -v /etc/tinyssh/sshkeydir &
}

if [ -e /etc/tinyssh/config ]; then
    . /etc/tinyssh/config
fi
. /scripts/functions

# On NFS mounts, wait until the network is configured.  On local mounts,
# configure the network in the background (in run_dropbear()) so someone
# with console access can enter the passphrase immediately.  (With the
# default ip=dhcp, configure_networking hangs for 5mins or so when the
# network is unavailable, for instance.)
[ "$BOOT" != nfs ] || configure_networking

run_tinyssh &
echo $! >/run/tinyssh.pid