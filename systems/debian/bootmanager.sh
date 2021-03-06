#!/bin/bash
# Install kernel & bootmanager
if system-arch "ARMHF"; then
    logLine "Setting up Bootmanager (UBOOT)";
    # TODO
else
    logLine "Setting up Bootmanager (GRUB)";
    
    # TODO: Detect Platform and install right kernel
    if system-arch "AMD64"; then
        if system-is-efi; then
      cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
. /etc/profile
DEBIAN_FRONTEND=noninteractive apt-get -yq install linux-image-amd64 grub-efi efibootmgr
EOF
        else
      cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
. /etc/profile
DEBIAN_FRONTEND=noninteractive apt-get -yq install linux-image-amd64 grub-pc
EOF
        fi;
    else
        logError "Unsupported System Type: $(system-arch)";
        exit 1;
    fi;
    chmod +x /tmp/mnt/root/chroot.sh;
    chroot /tmp/mnt/root /chroot.sh;
fi;

if isTrue "${CRYPT}"; then
    # Install crypt tools
    # dropbear-initramfs
  cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
. /etc/profile
DEBIAN_FRONTEND=noninteractive apt-get -yq install cryptsetup
EOF
    chroot /tmp/mnt/root /chroot.sh;
    
    # Append cryptsystem in crypttab
    if [[ -z $(cat /tmp/mnt/root/etc/crypttab | grep 'cryptsystem ') ]]; then
        echo cryptsystem PARTLABEL=system none luks > /tmp/mnt/root/etc/crypttab;
    fi;
    
    # Setup GRUB_ENABLE_CRYPTODISK=y in /etc/default/grub
    if [[ -z $(cat /tmp/mnt/root/etc/default/grub | grep "^GRUB_ENABLE_CRYPTODISK") ]]; then
        sed -i "s/#GRUB_ENABLE_CRYPTODISK=y/GRUB_ENABLE_CRYPTODISK=y/g" /tmp/mnt/root/etc/default/grub;
    fi;
    if [[ -z $(cat /tmp/mnt/root/etc/default/grub | grep "^GRUB_ENABLE_CRYPTODISK") ]]; then
        echo "GRUB_ENABLE_CRYPTODISK=y" >> /tmp/mnt/root/etc/default/grub;
    fi;
    
    # Enable hyperv_keyboard in /etc/initramfs-tools/modules
    if [[ -z $(cat /tmp/mnt/root/etc/initramfs-tools/modules | grep "^hyperv_keyboard$") ]]; then
        echo "hyperv_keyboard" >> /tmp/mnt/root/etc/initramfs-tools/modules;
    fi;
    
    # Setup CMDLINE
    if [[ -z $(cat /tmp/mnt/root/etc/default/grub | grep 'GRUB_CMDLINE_LINUX=\"cryptdevice\=') ]]; then
        sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=PARTLABEL=system:cryptsystem ip=::::::dhcp\"/g" /tmp/mnt/root/etc/default/grub;
        #sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=PARTLABEL=system:cryptsystem ip=192.168.168.3:::255.255.255.0::eth0:none\"/g" /tmp/mnt/root/etc/default/grub;
    fi;
    
    # Install TinySSH
  cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
. /etc/profile
DEBIAN_FRONTEND=noninteractive apt-get -yq remove dropbear-initramfs
DEBIAN_FRONTEND=noninteractive apt-get -yq install tinysshd ipsvd
systemctl disable tinysshd.socket
EOF
    chroot /tmp/mnt/root /chroot.sh;
    
    
    mkdir -p /tmp/mnt/root/etc/initramfs-tools/hooks/ /tmp/mnt/root/etc/initramfs-tools/scripts/init-premount/ /tmp/mnt/root/etc/tinyssh-initramfs/ /tmp/mnt/root/etc/initramfs-tools/scripts/init-bottom/;
    
    cp "${BASH_SOURCE%/*}/tinyssh.hook.sh" /tmp/mnt/root/etc/initramfs-tools/hooks/tinyssh;
    chmod +x /tmp/mnt/root/etc/initramfs-tools/hooks/tinyssh;
    
    cp "${BASH_SOURCE%/*}/tinyssh.premount.sh" /tmp/mnt/root/etc/initramfs-tools/scripts/init-premount/tinyssh;
    chmod +x /tmp/mnt/root/etc/initramfs-tools/scripts/init-premount/tinyssh;
    
    cp "${BASH_SOURCE%/*}/tinyssh.config" /tmp/mnt/root/etc/tinyssh-initramfs/config;
    chmod +x /tmp/mnt/root/etc/initramfs-tools/hooks/tinyssh;
    
    cp "${BASH_SOURCE%/*}/tinyssh.bottom.sh" /tmp/mnt/root/etc/initramfs-tools/scripts/init-bottom/tinyssh;
    chmod +x /tmp/mnt/root/etc/initramfs-tools/scripts/init-bottom/tinyssh;
    
    # Add current keys
    mkdir -p /tmp/mnt/root/etc/tinyssh/
    ssh-add -L | grep ssh-ed25519 > /tmp/mnt/root/etc/tinyssh/root_key;
fi;

# Install Grub
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
. /etc/profile

# Reinstall Kernel in /boot
apt-get reinstall \$(dpkg -l | grep -o "linux-image-[0-9][0-9\.\-]*-[A-Za-z0-9]*")

# Setup Boot
grub-install ${HARDDISK}
update-grub
update-initramfs -u -k all
EOF
#grub-mkconfig -o /boot/grub/grub.cfg
chroot /tmp/mnt/root /chroot.sh;