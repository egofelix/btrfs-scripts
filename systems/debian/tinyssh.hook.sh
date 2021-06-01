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

. /usr/share/initramfs-tools/hook-functions

## Needed for tinyssh
PATH=$PATH:/usr/sbin

tinyssh_warn() {
    echo "tinyssh: WARNING:" "$@" >&2
}

generate_keys() {
    if [ ! -d /etc/tinyssh/sshkeydir ]; then
	tinysshd-makekey /etc/tinyssh/sshkeydir
	if [ $? -eq 0 ]; then
	    echo "Generated tinyssh keys..."
	    return 0
	fi
    fi
    return 1
}


copy_openssh_keys() {
    local osshed25519="/etc/ssh/ssh_host_ed25519_key"

    local destdir="/etc/tinyssh/sshkeydir"

    local return_code=1

    if [ ! -x /usr/local/bin/tinyssh-convert ];then
	echo "tinyssh-convert script missing"
	exit 1
    fi

    if [ ! -d $destdir -a -x /usr/bin/tinyssh-convert ]; then
	mkdir $destdir
    fi

    if [ -s "$osshed25519" -a ! -s $destdir/.ed25519.sk -a ! -s $destdir/ed25519.pk -a -x /usr/bin/tinyssh-convert ]; then
	tinyssh-convert -f $osshed25519 -d $destdir
	if [ $? -eq 0 ]; then
	    return_code=0
	fi
    fi

    if [ $return_code -eq 0 ]; then
	echo "Converted keys from OpenSSH..."
    fi

    return $return_code
}

display_fingerprints() {
    if [ -d /etc/tinyssh/sshkeydir ]; then
	tinysshd-printkey /etc/tinyssh/sshkeydir
    fi
}

#### BEGIN REAL PROCESSING


## Only install tinyssh if we have an encrypted partition
[ -r /etc/crypttab ] || exit 0


copy_exec /usr/sbin/tinysshd /sbin
LIBC_DIR=$(ldd /usr/sbin/tinysshd | sed -nr 's#.* => (/lib.*)/libc\.so\.[0-9.-]+ \(0x[[:xdigit:]]+\)$#\1#p')
find -L "$LIBC_DIR" -maxdepth 1 -name 'libnss_files.*' -type f | while read so; do
    copy_exec "$so"
done

# Create root dir
home=$(mktemp -d "$DESTDIR/root-XXXXXX")
chmod 0700 "$home"
for x in passwd group; do echo "$x: files"; done >"$DESTDIR/etc/nsswitch.conf"
echo "root:*:0:0::${home#$DESTDIR}:/bin/sh" >"$DESTDIR/etc/passwd"
echo "root:!:0:" >"$DESTDIR/etc/group"

# Copy config
mkdir -p "$DESTDIR/etc/tinyssh"
if [ -e /etc/tinyssh-initramfs/config ]; then
    cp -p "/etc/tinyssh-initramfs/config" "$DESTDIR/etc/tinyssh/"
fi

umask 0022

# Copy host keys or generate keys
copy_openssh_keys || generate_keys
display_fingerprints

# Copy authorized_keys from etc dir
if [ ! -r /etc/tinyssh-initramfs/authorized_keys ]; then
    echo "Add authorized keys in /etc/tinyssh-initramfs/authorized_keys"
    exit 1
fi

mkdir -m0700 "$home/.ssh"
if [ -e /etc/tinyssh-initramfs/authorized_keys ]; then
    cat /etc/tinyssh-initramfs/authorized_keys
fi >"$home/.ssh/authorized_keys"

# Check that authorized keys are in the right format
if ! grep -qE '^(ssh-ed25519) ' "$home/.ssh/authorized_keys"; then
    tinyssh_warn "Invalid authorized_keys file, only ed25519 keys allowe,d remote unlocking of cryptroot via SSH won't work!"
fi

# necessary for tinyssh private keys
cp -a /etc/tinyssh "$DESTDIR/etc/"

# vim: set sts=4 shiftwidth=4