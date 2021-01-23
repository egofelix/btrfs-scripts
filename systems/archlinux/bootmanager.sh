#!/bin/bash
logLine "Setting up Bootmanager (GRUB)";

# Install kernel & bootmanager
if [[ $(getSystemModel) = "CUBIETRUCK" ]]; then
	cat > /tmp/mnt/root/chroot.sh <<- EOF
pacman -S --noconfirm linux-armv7 efibootmgr
yes | pacman -S --noconfigm uboot-cubietruck uboot-tools
EOF

	cat > /tmp/mnt/root/boot/boot.txt <<- EOF
# After modifying, run ./mkscr
setenv bootpart 2;
EOF
	if isTrue "${CRYPTED}"; then
		cat >> /tmp/mnt/root/boot/boot.txt <<- EOF
setenv bootargs console=${console} cryptdevice=PARTLABEL=system:cryptsystem root=/dev/mapper/cryptsystem rw rootwait;
EOF
	else
		cat >> /tmp/mnt/root/boot/boot.txt <<- EOF
setenv bootargs console=${console} root=PARTLABEL=system rw rootwait;
EOF
	fi;
	
	cat >> /tmp/mnt/root/boot/boot.txt <<- EOF
if load \${devtype} \${devnum}:\${bootpart} \${kernel_addr_r} /zImage; then
  if load \${devtype} \${devnum}:\${bootpart} \${fdt_addr_r} /dtbs/\${fdtfile}; then
    if load \${devtype} \${devnum}:\${bootpart} \${ramdisk_addr_r} /initramfs-linux.img; then
      bootz \${kernel_addr_r} \${ramdisk_addr_r}:\${filesize} \${fdt_addr_r};
    else
      bootz \${kernel_addr_r} - \${fdt_addr_r};
    fi;
  fi;
fi	
EOF

	# Recompile boot.txt -> boot.scr
	cat > /tmp/mnt/root/chroot.sh <<- EOF
cd /boot
./mkscr
EOF
	chroot /tmp/mnt/root /chroot.sh
else
	cat > /tmp/mnt/root/chroot.sh <<- EOF
pacman -S --noconfirm linux grub efibootmgr
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
	
	# Get current hooks
	HOOKS="HOOKS=($(source /tmp/mnt/root/etc/mkinitcpio.conf && echo ${HOOKS[@]}))"
	
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
	HOOKS="HOOKS=($(source /tmp/mnt/root/etc/mkinitcpio.conf && echo ${HOOKS[@]}))"
	HOOKS=${HOOKS/netconf/}
	HOOKS=${HOOKS/tinyssh/}
	HOOKS=${HOOKS/encryptssh/}
	sed -i "s/HOOKS=.*/${HOOKS}/g" /tmp/mnt/root/etc/mkinitcpio.conf
fi;

# Add usr hook to mkinitcpio.conf if usr is on a subvolume
if [[ ! -z $(LANG=C mount | grep ' /tmp/mnt/root/usr type ') ]]; then
	HOOKS="HOOKS=($(source /tmp/mnt/root/etc/mkinitcpio.conf && if [[ ${HOOKS[@]} != *"usr"* ]]; then HOOKS+=(usr); fi && echo ${HOOKS[@]} | xargs echo -n))"
	sed -i "s/HOOKS=.*/${HOOKS}/g" /tmp/mnt/root/etc/mkinitcpio.conf
fi;

# Install Grub
cat > /tmp/mnt/root/chroot.sh <<- EOF
mkinitcpio -P
grub-install ${DRIVE_ROOT}
grub-mkconfig -o /boot/grub/grub.cfg
EOF
chroot /tmp/mnt/root /chroot.sh;