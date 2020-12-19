#!/bin/bash

if [[ ( $(getSystemType) = "ARMHF" ) ]]; then
    # Install uboot
	cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
yes n | pacman -S --noconfirm uboot-cubietruck uboot-tools
mkinitcpio -P
EOF
	chroot /tmp/mnt/root /chroot.sh &> /dev/null
else
    # Install Grub
	cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
pacman -S --noconfirm grub efibootmgr
EOF
	chroot /tmp/mnt/root /chroot.sh &> /dev/null

    if isTrue "${CRYPTED}"; then
		# Setup Grub for Cryptsetup
		echo "GRUB_ENABLE_CRYPTODISK=y" >> /tmp/mnt/root/etc/default/grub
		REPLACEMENT='GRUB_CMDLINE_LINUX="cryptdevice=PARTLABEL=system:cryptsystem"'

		sed -i "s;GRUB_CMDLINE_LINUX=.*;${REPLACEMENT};g" /tmp/mnt/root/etc/default/grub
	fi;

	# Setup Grub
	cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
mkinitcpio -P
grub-install
grub-mkconfig -o /boot/grub/grub.cfg
EOF
	chroot /tmp/mnt/root /chroot.sh &> /dev/null
fi;