#!/bin/bash

# create script

# Install Kernel
if [[ ( $(getSystemType) = "ARMHF" ) ]]; then
	cat > /tmp/mnt/root/chroot.sh <<- EOF
# install grub
pacman -Sy --noconfirm linux-armv7
EOF
else
	cat > /tmp/mnt/root/chroot.sh <<- EOF
# install grub
pacman -Sy --noconfirm linux
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
pacman -S --noconfirm btrfs-progs openssh linux-firmware
EOF
chroot /tmp/mnt/root /chroot.sh;

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
systemctl enable systemd-timesyncd
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