#!/bin/bash
# Install kernel & bootmanager
if system-arch "ARMHF"; then
    logLine "Setting up Bootmanager (UBOOT)";
  cat > /tmp/mnt/root/chroot.sh <<- EOF
pacman -S --noconfirm linux-armv7 efibootmgr
yes | pacman -S --noconfirm uboot-cubietruck uboot-tools
EOF
    chmod +x /tmp/mnt/root/chroot.sh;
    chroot /tmp/mnt/root /chroot.sh;
    
  cat > /tmp/mnt/root/boot/boot.txt <<- EOF
# After modifying, run ./mkscr
setenv bootpart 3;
EOF
    if isTrue "${CRYPTED}"; then
    cat >> /tmp/mnt/root/boot/boot.txt <<- EOF
setenv bootargs console=\${console} cryptdevice=PARTLABEL=system:cryptsystem root=/dev/mapper/cryptsystem rw rootwait;
EOF
    else
    cat >> /tmp/mnt/root/boot/boot.txt <<- EOF
setenv bootargs console=\${console} root=PARTLABEL=system rw rootwait;
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
    logLine "Setting up Bootmanager (GRUB)";
  cat > /tmp/mnt/root/chroot.sh <<- EOF
pacman -S --noconfirm linux grub efibootmgr
EOF
    chmod +x /tmp/mnt/root/chroot.sh;
    chroot /tmp/mnt/root /chroot.sh;
fi;

USE_SYSTEMD_INIT="true";

if isTrue ${USE_SYSTEMD_INIT};
then
    # Setup systemd hooks
    HOOKS="HOOKS=(base autodetect modconf block filesystems keyboard fsck systemd systemd-tool)"
    sed -i "s/HOOKS=.*/${HOOKS}/g" /tmp/mnt/root/etc/mkinitcpio.conf
    
    # Install systemd-tools and configure
    cat > /tmp/mnt/root/chroot.sh <<- EOF
pacman -S --noconfirm mkinitcpio-systemd-tool
systemctl enable initrd-debug-progs.service
systemctl enable initrd-sysroot-mount.service
EOF
    chroot /tmp/mnt/root /chroot.sh;
    
    # give systemd hint for /sysroot
    cat > /tmp/mnt/root/etc/mkinitcpio-systemd-tool/config/fstab <<- EOF
${PART_SYSTEM}         /sysroot                btrfs           rw,relatime,space_cache,subvol=/root-data       0 0
EOF
    
    if isTrue "${CRYPT}"; then
        # Append cryptsystem in crypttab
        if [[ -z $(cat /tmp/mnt/root/etc/crypttab | grep 'cryptsystem ') ]]; then
            echo cryptsystem PARTLABEL=system none luks > /tmp/mnt/root/etc/crypttab
        fi;
        
        # Copy crypttab
        cp /tmp/mnt/root/etc/crypttab /tmp/mnt/root/etc/mkinitcpio-systemd-tool/config/crypttab;
        
        cat > /tmp/mnt/root/chroot.sh <<- EOF
systemctl enable initrd-cryptsetup.path
EOF
        chroot /tmp/mnt/root /chroot.sh;
    fi;
elif isTrue "${CRYPT}";
then
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
    
    # Add current keys
    mkdir -p /tmp/mnt/root/etc/tinyssh/
    ssh-add -L | grep ssh-ed25519 > /tmp/mnt/root/etc/tinyssh/root_key;
    
    # Add usr hook to mkinitcpio.conf if usr is on a subvolume
    if [[ ! -z $(LANG=C mount | grep ' /tmp/mnt/root/usr type ') ]]; then
        HOOKS="HOOKS=($(source /tmp/mnt/root/etc/mkinitcpio.conf && if [[ ${HOOKS[@]} != *"usr"* ]]; then HOOKS+=(usr); fi && echo ${HOOKS[@]} | xargs echo -n))"
        sed -i "s/HOOKS=.*/${HOOKS}/g" /tmp/mnt/root/etc/mkinitcpio.conf
    fi;
else
    # Remove HOOKS netconf tinyssh encryptssh
    HOOKS="HOOKS=($(source /tmp/mnt/root/etc/mkinitcpio.conf && echo ${HOOKS[@]}))"
    HOOKS=${HOOKS/netconf/}
    HOOKS=${HOOKS/tinyssh/}
    HOOKS=${HOOKS/encryptssh/}
    sed -i "s/HOOKS=.*/${HOOKS}/g" /tmp/mnt/root/etc/mkinitcpio.conf
    
    # Add usr hook to mkinitcpio.conf if usr is on a subvolume
    if [[ ! -z $(LANG=C mount | grep ' /tmp/mnt/root/usr type ') ]]; then
        HOOKS="HOOKS=($(source /tmp/mnt/root/etc/mkinitcpio.conf && if [[ ${HOOKS[@]} != *"usr"* ]]; then HOOKS+=(usr); fi && echo ${HOOKS[@]} | xargs echo -n))"
        sed -i "s/HOOKS=.*/${HOOKS}/g" /tmp/mnt/root/etc/mkinitcpio.conf
    fi;
fi;

# Install Grub
cat > /tmp/mnt/root/chroot.sh <<- EOF
mkinitcpio -P
grub-install ${HARDDISK}
grub-mkconfig -o /boot/grub/grub.cfg
EOF
chroot /tmp/mnt/root /chroot.sh;