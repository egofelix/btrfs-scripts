#!/bin/bash

# create script

# Install Kernel
if [[ ( $(getSystemType) = "ARMHF" ) ]]; then
	cat > /tmp/mnt/root/chroot.sh <<- EOF
DEBIAN_FRONTEND=noninteractive apt-get -yq install linux-image-armhf;
EOF
else
	cat > /tmp/mnt/root/chroot.sh <<- EOF
DEBIAN_FRONTEND=noninteractive apt-get -yq install linux-image-generic;
EOF
fi;
chmod +x /tmp/mnt/root/chroot.sh
chroot /tmp/mnt/root /chroot.sh;

# Install default packages
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash

# Set root password
echo -e "root\nroot" | passwd root

# Needed Packages
DEBIAN_FRONTEND=noninteractive apt-get -yq install btrfs-progs openssh linux-firmware
EOF
if isTrue "${CRYPTED}"; then
	cat >> /tmp/mnt/root/chroot.sh <<- EOF
DEBIAN_FRONTEND=noninteractive apt-get -yq install cryptsetup mkinitcpio-netconf mkinitcpio-tinyssh mkinitcpio-utils
EOF
fi;
chroot /tmp/mnt/root /chroot.sh;

# Setup crypto
if isTrue "${CRYPTED}"; then
    # Create crypttab
	echo cryptsystem PARTLABEL=system none luks > /tmp/mnt/root/etc/crypttab
	
	# Add the /usr/lib/libgcc_s.so.1 to BINARIES in /etc/mkinitcpio.conf
	BINARIES="BINARIES=($(source /tmp/mnt/root/etc/mkinitcpio.conf && if [[ ${BINARIES[@]} != *"/usr/lib/libgcc_s.so.1"* ]]; then BINARIES+=(/usr/lib/libgcc_s.so.1); fi && echo ${BINARIES[@]} | xargs echo -n))"
	sed -i "s#BINARIES=.*#${BINARIES}#g" /tmp/mnt/root/etc/mkinitcpio.conf
	
	# Setup HOOKS
	HOOKS="HOOKS=(base udev autodetect modconf block keyboard keymap netconf tinyssh encryptssh filesystems fsck)"
	sed -i "s/HOOKS=.*/${HOOKS}/g" /tmp/mnt/root/etc/mkinitcpio.conf
fi;

# Add usr hook to mkinitcpio.conf if usr is on a subvolume
if [[ ${SUBVOLUMES} == *"usr"* ]]; then
	HOOKS="HOOKS=($(source /tmp/mnt/root/etc/mkinitcpio.conf && if [[ ${HOOKS[@]} != *"usr"* ]]; then HOOKS+=(usr); fi && echo ${HOOKS[@]} | xargs echo -n))"
	sed -i "s/HOOKS=.*/${HOOKS}/g" /tmp/mnt/root/etc/mkinitcpio.conf
fi;

# Setup sshd
sed -i 's/^#PermitRootLogin .*/PermitRootLogin yes/' /tmp/mnt/root/etc/ssh/sshd_config
sed -i 's/^PermitRootLogin .*/PermitRootLogin yes/' /tmp/mnt/root/etc/ssh/sshd_config

# Install bootmanager
source "${BASH_SOURCE%/*}/bootmanager.sh"

# Setup Network
rm -f /tmp/mnt/root/etc/network/interfaces
rm -f /tmp/mnt/root/etc/network/interfaces.d/*
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable sshd
EOF
chroot /tmp/mnt/root /chroot.sh &> /dev/null
cat > /tmp/mnt/root/etc/systemd/network/en.network <<- EOM
[Match]
Name=en*

[Network]
DHCP=yes
EOM
cat > /tmp/mnt/root/etc/systemd/network/eth.network <<- EOM
[Match]
Name=eth*

[Network]
DHCP=yes
EOM

# Remove chroot file
rm -f /tmp/mnt/root/chroot.sh