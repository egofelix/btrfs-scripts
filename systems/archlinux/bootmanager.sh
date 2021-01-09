#!/bin/bash
logLine "Setting up Bootmanager (GRUB)";

# Install Grub & efibootmgr
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
	
	# Setup HOOKS
	HOOKS="HOOKS=(base udev autodetect modconf block keyboard keymap netconf tinyssh encryptssh filesystems fsck)"
	sed -i "s/HOOKS=.*/${HOOKS}/g" /tmp/mnt/root/etc/mkinitcpio.conf
	
	# Setup Grub for Cryptsetup
	sed -i "s/#GRUB_ENABLE_CRYPTODISK/GRUB_ENABLE_CRYPTODISK/g" /tmp/mnt/root/etc/default/grub
	
	# Setup CMDLINE
	if [[ -z $(cat /tmp/mnt/root/etc/default/grub | grep 'GRUB_CMDLINE_LINUX=\"cryptdevice\=') ]]; then
		sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=PARTLABEL=system:cryptsystem ip=:::::eth0:dhcp\"/g" /tmp/mnt/root/etc/default/grub
	fi;
fi;

# Add usr hook to mkinitcpio.conf if usr is on a subvolume
if [[ ! -z $(LANG=C mount | grep ' /tmp/mnt/root/usr type ') ]]; then
	HOOKS="HOOKS=($(source /tmp/mnt/root/etc/mkinitcpio.conf && if [[ ${HOOKS[@]} != *"usr"* ]]; then HOOKS+=(usr); fi && echo ${HOOKS[@]} | xargs echo -n))"
	sed -i "s/HOOKS=.*/${HOOKS}/g" /tmp/mnt/root/etc/mkinitcpio.conf
fi;

# Install Grub
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