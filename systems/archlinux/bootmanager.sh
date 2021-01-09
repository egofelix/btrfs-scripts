#!/bin/bash
logLine "Setting up Bootmanager (GRUB)";

if isEfiSystem; then
	# Install Grub
	cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
pacman -S --noconfirm grub efibootmgr
EOF
else
	# Install Grub
	cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
pacman -S --noconfirm grub
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
if isEfiSystem; then
	cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
mkinitcpio -P
grub-install
grub-mkconfig -o /boot/grub/grub.cfg
EOF
else
	cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
mkinitcpio -P
grub-install ${DRIVE_ROOT}
grub-mkconfig -o /boot/grub/grub.cfg
EOF
fi;
chroot /tmp/mnt/root /chroot.sh;