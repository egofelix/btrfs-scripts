#!/bin/bash

# create script
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash

# Set root password
echo -e "root\nroot" | passwd root
EOF

if isTrue "${CRYPTED}"; then
	cat >> /tmp/mnt/root/chroot.sh <<- EOF
# install grub
pacman -Sy --noconfirm linux linux-firmware grub efibootmgr btrfs-progs cryptsetup
EOF
else
	cat >> /tmp/mnt/root/chroot.sh <<- EOF
# install grub
pacman -Sy --noconfirm linux linux-firmware grub efibootmgr btrfs-progs
EOF
fi;

# Run script
chmod +x /tmp/mnt/root/chroot.sh
chroot /tmp/mnt/root /chroot.sh

# Setup crypto
if isTrue "${CRYPTED}"; then
	echo cryptsystem PARTLABEL=system none luks > /tmp/mnt/root/etc/crypttab
	echo cryptsystem PARTLABEL=system none luks > /tmp/mnt/root/etc/crypttab.initramfs
	
	# Add hooks for cryptsetup to mkinitcpio.conf
	HOOKS="HOOKS=($(source /tmp/mnt/root/etc/mkinitcpio.conf && HOOKS+=(encrypt keymap keyboard) && echo ${HOOKS[@]} | xargs echo -n))"
	sed -i "s/HOOKS=.*/${HOOKS}/g" /tmp/mnt/root/etc/mkinitcpio.conf
	
	# Setup Grub for Cryptsetup
	echo "GRUB_ENABLE_CRYPTODISK=y" >> /tmp/mnt/root/etc/default/grub
	REPLACEMENT='GRUB_CMDLINE_LINUX="cryptdevice=/dev/sda3:cryptsystem"'
	
	sed -i "s;GRUB_CMDLINE_LINUX=.*;${REPLACEMENT};g" /tmp/mnt/root/etc/default/grub
fi;

# Install grub
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
mkinitcpio -P
grub-install
grub-mkconfig -o /boot/grub/grub.cfg
EOF
chroot /tmp/mnt/root /chroot.sh