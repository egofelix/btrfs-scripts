#!/bin/bash

# Install locales
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
source /etc/profile
DEBIAN_FRONTEND=noninteractive apt-get -yq install locales
EOF
chmod +x /tmp/mnt/root/chroot.sh;
chroot /tmp/mnt/root /chroot.sh;

# Locale-gen
cat > /tmp/mnt/root/etc/locale.gen <<- EOF
de_DE ISO-8859-1
de_DE.UTF-8 UTF-8
de_DE@euro ISO-8859-15
en_US ISO-8859-1
en_US.ISO-8859-15 ISO-8859-15
en_US.UTF-8 UTF-8
EOF
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
source /etc/profile
locale-gen
update-locale
EOF
chmod +x /tmp/mnt/root/chroot.sh;
chroot /tmp/mnt/root /chroot.sh;

# Install Kernel & Software
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
source /etc/profile
DEBIAN_FRONTEND=noninteractive apt-get -yq install btrfs-progs openssh-server git
EOF
chmod +x /tmp/mnt/root/chroot.sh;
chroot /tmp/mnt/root /chroot.sh;

# Reset root password
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
source /etc/profile
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

# Disable old networking, we will use systemd-networkd
cat > /tmp/mnt/root/chroot.sh <<- EOF
systemctl disable networking
EOF
chroot /tmp/mnt/root /chroot.sh;
rm -f /tmp/mnt/root/etc/network/interfaces;
rm -f /tmp/mnt/root/etc/network/interfaces.d/*;

# Install btrfs-scripts
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
source /etc/profile
git clone https://github.com/egofelix/btrfs-scripts.git /opt/btrfs-scripts
EOF
chroot /tmp/mnt/root /chroot.sh &> /dev/null;

# Enable services
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
source /etc/profile
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