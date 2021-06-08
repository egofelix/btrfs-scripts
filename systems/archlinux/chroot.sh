#!/bin/bash

# Install Kernel & Software
cat > /tmp/mnt/root/chroot.sh <<- EOF
pacman -Sy --noconfirm linux-firmware btrfs-progs openssh git
EOF
chmod +x /tmp/mnt/root/chroot.sh;
chroot /tmp/mnt/root /chroot.sh;

# Reset root password
cat > /tmp/mnt/root/chroot.sh <<- EOF
echo -e "root\nroot" | passwd root
EOF
chroot /tmp/mnt/root /chroot.sh;

# Setup ssh
mkdir -p /tmp/mnt/root/root/.ssh
ssh-add -L > /tmp/mnt/root/root/.ssh/authorized_keys;
if [[ -s /tmp/mnt/root/root/.ssh/authorized_keys ]]; then
    # Root has keys
    sed -i 's/^#PermitRootLogin .*/PermitRootLogin prohibit-password/' /tmp/mnt/root/etc/ssh/sshd_config;
    sed -i 's/^PermitRootLogin .*/PermitRootLogin prohibit-password/' /tmp/mnt/root/etc/ssh/sshd_config;
    
    # Lock root password
    cat > /tmp/mnt/root/chroot.sh <<- EOF
passwd -l root
EOF
    chroot /tmp/mnt/root /chroot.sh;
else
    sed -i 's/^#PermitRootLogin .*/PermitRootLogin yes/' /tmp/mnt/root/etc/ssh/sshd_config;
    sed -i 's/^PermitRootLogin .*/PermitRootLogin yes/' /tmp/mnt/root/etc/ssh/sshd_config;
fi;

# Remove old network settings
rm -f /tmp/mnt/root/etc/network/interfaces;
rm -f /tmp/mnt/root/etc/network/interfaces.d/*;

# Install btrfs-scripts
cat > /tmp/mnt/root/chroot.sh <<- EOF
git clone https://github.com/egofelix/btrfs-scripts.git /opt/btrfs-scripts
EOF
chroot /tmp/mnt/root /chroot.sh &> /dev/null;

# Enable services
cat > /tmp/mnt/root/chroot.sh <<- EOF
systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable systemd-timesyncd
systemctl enable sshd
EOF
chroot /tmp/mnt/root /chroot.sh &> /dev/null;

# Enable DHCP on all interfaces
cat > /tmp/mnt/root/etc/systemd/network/eth.network <<- EOM
[Match]
Name=eth* en*

[Network]
DHCP=yes
EOM

# Setup bootmanager
source "${BASH_SOURCE%/*}/bootmanager.sh";

# Remove chroot file
rm -f /tmp/mnt/root/chroot.sh;