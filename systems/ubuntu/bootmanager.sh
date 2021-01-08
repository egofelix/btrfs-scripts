#!/bin/bash
logLine "Setting up Bootmanager (GRUB)";

# Install Grub
if [[ "${BIOSTYPE}" == "EFI" ]]; then
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
DEBIAN_FRONTEND=noninteractive apt-get -yq install grub-efi
EOF
else
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
DEBIAN_FRONTEND=noninteractive apt-get -yq install grub-pc
EOF
fi;
chmod +x /tmp/mnt/root/chroot.sh;
chroot /tmp/mnt/root /chroot.sh;

if isTrue "${CRYPTED}"; then
	# Setup Grub for Cryptsetup
	sed -i "s/#GRUB_ENABLE_CRYPTODISK/GRUB_ENABLE_CRYPTODISK/g" /tmp/mnt/root/etc/default/grub
	sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=PARTLABEL=system:cryptsystem ip=:::::eth0:dhcp\"/g" /tmp/mnt/root/etc/default/grub
fi;

# Setup Grub
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
mkinitcpio -P
grub-install
grub-mkconfig -o /boot/grub/grub.cfg
EOF
chroot /tmp/mnt/root /chroot.sh;