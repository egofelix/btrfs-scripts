#!/bin/bash

# create script
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
. /etc/profile

# Set root password
echo -e "root\nroot" | passwd root

DEBIAN_FRONTEND=noninteractive apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq locales console-data dirmngr btrfs-progs openssh-server

echo "btrfs" >> /etc/initramfs-tools/modules
EOF

# Install Kernel
if [[ ( $(getSystemType) = "ARMHF" ) ]]; then
	echo "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq linux-image-armmp-lpae" >> /mnt/chroot.sh
else
	echo "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq linux-image-amd64" >> /mnt/chroot.sh
fi;

if isTrue "${CRYPTED}"; then
	# Install cryptsetup & dropbear
	cat >> /tmp/mnt/root/chroot.sh <<- EOF
# install grub
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq cryptsetup dropbear-initramfs
EOF
fi;

# Run script
chmod +x /tmp/mnt/root/chroot.sh
chroot /tmp/mnt/root /chroot.sh &> /dev/null

# Setup locale
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
. /etc/profile

sed -i '/de_DE.UTF-8/s/^#//' /etc/locale.gen
sed -i '/en_US.UTF-8/s/^#//' /etc/locale.gen
locale-gen
echo -e 'LANG="en_US.UTF-8"\nLANGUAGE="en_US.UTF-8"\nLC_ALL="en_US.UTF-8"\n' > /etc/default/locale

EOF

chroot /tmp/mnt/root /chroot.sh &> /dev/null

# Setup sshd
sed -i 's/^#PermitRootLogin .*/PermitRootLogin yes/' /tmp/mnt/root/etc/ssh/sshd_config
sed -i 's/^PermitRootLogin .*/PermitRootLogin yes/' /tmp/mnt/root/etc/ssh/sshd_config

# Install grub
if [[ ( $(getSystemType) = "ARMHF" ) ]]; then
	echo WILL USE GRUB-EFI-ARM
	cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
. /etc/profile

DEBIAN_FRONTEND=noninteractive apt-get install -y -qq grub-efi-arm
grub-install --removable --target=arm-efi --boot-directory=/boot --efi-directory=/boot/efi
EOF
else
	echo WILL USE GRUB-EFI
	cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
. /etc/profile

DEBIAN_FRONTEND=noninteractive apt-get install -y -qq grub-efi
grub-install --target=x86_64-efi --boot-directory=/boot --efi-directory=/boot/efi
EOF
fi;
echo "update-initramfs -k all -u" >> /mnt/chroot.sh
echo "grub-mkconfig -o /boot/grub/grub.cfg" >> /mnt/chroot.sh
chroot /tmp/mnt/root /chroot.sh &> /dev/null

# Setup Network
rm -f /tmp/mnt/root/etc/network/interfaces
rm -f /tmp/mnt/root/etc/network/interfaces.d/*
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
. /etc/profile

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

# Resotre resolv.conf
rm -f /tmp/mnt/root/etc/resolv.conf
ln -s /run/systemd/resolve/stub-resolv.conf /tmp/mnt/root/etc/resolv.conf

# Remove chroot file
rm -f /tmp/mnt/root/chroot.sh