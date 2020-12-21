#!/bin/bash
if [[ ( $(getSystemType) = "ARMHF" ) ]]; then
	logLine "Setting up Bootmanager (UBOOT)";

    # Install uboot
	cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
yes n | pacman -S --noconfirm uboot-cubietruck uboot-tools
mkinitcpio -P
EOF
    
	chmod +x /tmp/mnt/root/chroot.sh;
	chroot /tmp/mnt/root /chroot.sh;
	
	# Setup boot.txt for seperated boot partition
	if [ -f "/tmp/mnt/root/etc/boot.txt" ]; then
		rm -f /tmp/mnt/root/boot/boot.txt
		cp /tmp/mnt/root/etc/boot.txt /tmp/mnt/root/boot/boot.txt
	else
		if isTrue "${CRYPTED}"; then
			cat > /tmp/mnt/root/boot/boot.txt <<- EOF
# After modifying, run ./mkscr

setenv bootpart 1;
setenv bootargs cryptdevice=PARTLABEL=system:cryptsystem root=/dev/mapper/cryptsystem rw rootwait console=ttyAMA0,115200 console=tty1;

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
		else
			cat > /tmp/mnt/root/boot/boot.txt <<- EOF
# After modifying, run ./mkscr

setenv bootpart 1;
setenv bootargs console=${console} root=PARTLABEL=system rw rootwait;

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
		fi;
	fi;

	# Recompile boot.txt -> boot.scr
	cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
cd /boot
./mkscr
EOF
	chroot /tmp/mnt/root /chroot.sh;
else
	logLine "Setting up Bootmanager (GRUB)";
	
    # Install Grub
	cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
pacman -S --noconfirm grub efibootmgr
EOF
    
	chmod +x /tmp/mnt/root/chroot.sh;
	chroot /tmp/mnt/root /chroot.sh;

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
	chroot /tmp/mnt/root /chroot.sh;
fi;