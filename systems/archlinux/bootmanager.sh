#!/bin/bash
logLine "Setting up Bootmanager (GRUB)";

# Install kernel & grub & efibootmgr
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
pacman -S --noconfirm linux grub efibootmgr
EOF
chmod +x /tmp/mnt/root/chroot.sh;
chroot /tmp/mnt/root /chroot.sh;

if isTrue "${CRYPTED}"; then
    # Install crypt tools
	cat > /tmp/mnt/root/chroot.sh <<- EOF
pacman -S --noconfirm cryptsetup mkinitcpio-netconf mkinitcpio-tinyssh mkinitcpio-utils
EOF
    chroot /tmp/mnt/root /chroot.sh;

    # Append cryptsystem in crypttab
	if [[ -z $(cat /tmp/mnt/root/etc/crypttab | grep 'cryptsystem ') ]]; then
	  echo cryptsystem PARTLABEL=system none luks > /tmp/mnt/root/etc/crypttab
	fi;
	
	# Add the /usr/lib/libgcc_s.so.1 to BINARIES in /etc/mkinitcpio.conf
	BINARIES="BINARIES=($(source /tmp/mnt/root/etc/mkinitcpio.conf && if [[ ${BINARIES[@]} != *"/usr/lib/libgcc_s.so.1"* ]]; then BINARIES+=(/usr/lib/libgcc_s.so.1); fi && echo ${BINARIES[@]} | xargs echo -n))"
	sed -i "s#BINARIES=.*#${BINARIES}#g" /tmp/mnt/root/etc/mkinitcpio.conf
	
	# Get current hooks
	HOOKS="HOOKS=($(source /tmp/mnt/root/etc/mkinitcpio.conf && echo ${HOOKS[@]))"
	
	# Remove these hooks
    HOOKS=${HOOKS/keyboard/}
	HOOKS=${HOOKS/keymap/}
	HOOKS=${HOOKS/netconf/}
	HOOKS=${HOOKS/tinyssh/}
	HOOKS=${HOOKS/encryptssh/}
	
	# Insert hooks before filesystems
	HOOKS=${HOOKS/filesystems/keyboard keymap netconf tinyssh encryptssh filesystems}
	sed -i "s/HOOKS=.*/${HOOKS}/g" /tmp/mnt/root/etc/mkinitcpio.conf
	
	# Setup GRUB_ENABLE_CRYPTODISK=y in /etc/default/grub
	if [[ -z $(cat /tmp/mnt/root/etc/default/grub | grep "^GRUB_ENABLE_CRYPTODISK") ]]; then
		sed -i "s/#GRUB_ENABLE_CRYPTODISK=y/GRUB_ENABLE_CRYPTODISK=y/g" /tmp/mnt/root/etc/default/grub
	fi;
	if [[ -z $(cat /tmp/mnt/root/etc/default/grub | grep "^GRUB_ENABLE_CRYPTODISK") ]]; then
		echo "GRUB_ENABLE_CRYPTODISK=y" >> /tmp/mnt/root/etc/default/grub
	fi;
	
	# Setup CMDLINE
	if [[ -z $(cat /tmp/mnt/root/etc/default/grub | grep 'GRUB_CMDLINE_LINUX=\"cryptdevice\=') ]]; then
		sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=PARTLABEL=system:cryptsystem ip=:::::eth0:dhcp\"/g" /tmp/mnt/root/etc/default/grub
	fi;
else
	# Remove HOOKS netconf tinyssh encryptssh
	HOOKS="HOOKS=($(source /tmp/mnt/root/etc/mkinitcpio.conf && echo ${HOOKS[@]))"
	HOOKS=${HOOKS/netconf/}
	HOOKS=${HOOKS/tinyssh/}
	HOOKS=${HOOKS/encryptssh/}
	sed -i "s/HOOKS=.*/${HOOKS}/g" /tmp/mnt/root/etc/mkinitcpio.conf
fi;

# Install Grub
cat > /tmp/mnt/root/chroot.sh <<- EOF
mkinitcpio -P
grub-install ${DRIVE_ROOT}
grub-mkconfig -o /boot/grub/grub.cfg
EOF
chroot /tmp/mnt/root /chroot.sh;