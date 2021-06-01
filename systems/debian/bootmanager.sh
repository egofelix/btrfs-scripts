#!/bin/bash
# Install kernel & bootmanager
if [[ $(getSystemType) = "ARMHF" ]]; then
  logLine "Setting up Bootmanager (UBOOT)";
  # TODO
else
  logLine "Setting up Bootmanager (GRUB)";

  # TODO: Detect Platform and install right kernel
  if [[ $(getSystemType) = "AMD64" ]]; then
    if isEfiSystem; then
      cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
source /etc/profile
DEBIAN_FRONTEND=noninteractive apt-get -yq install linux-image-amd64 grub-efi efibootmgr
EOF
    else
      cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
source /etc/profile
DEBIAN_FRONTEND=noninteractive apt-get -yq install linux-image-amd64 grub-pc
EOF
    fi;
  else
    logError "Unsupported System Type: $(getSystemType)";
    exit 1;
  fi;
  chmod +x /tmp/mnt/root/chroot.sh;
  chroot /tmp/mnt/root /chroot.sh;
fi;

if isTrue "${CRYPTED}"; then
  # Install crypt tools
  cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
source /etc/profile
DEBIAN_FRONTEND=noninteractive apt-get -yq install cryptsetup
EOF
  chroot /tmp/mnt/root /chroot.sh;

  # Append cryptsystem in crypttab
  if [[ -z $(cat /tmp/mnt/root/etc/crypttab | grep 'cryptsystem ') ]]; then
    echo cryptsystem PARTLABEL=system none luks > /tmp/mnt/root/etc/crypttab
  fi;

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

  # Install TinySSH Hook
  mkdir -p /tmp/mnt/root/etc/initramfs-tools/hooks/ /tmp/mnt/root/etc/initramfs-tools/scripts/init-premount/ /tmp/mnt/root/etc/tinyssh-initramfs/
  cp "${BASH_SOURCE%/*}/tinyssh.hook.sh" /tmp/mnt/root/etc/initramfs-tools/hooks/tinyssh
  chmod +x /tmp/mnt/root/etc/initramfs-tools/hooks/tinyssh
  cp "${BASH_SOURCE%/*}/tinyssh.premount.sh" /tmp/mnt/root/etc/initramfs-tools/scripts/init-premount/tinyssh
  chmod +x /tmp/mnt/root/etc/initramfs-tools/scripts/init-premount/tinyssh
  cp "${BASH_SOURCE%/*}/tinyssh.config" /tmp/mnt/root/etc/tinyssh-initramfs/config
fi;

# Install Grub
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
source /etc/profile
update-initramfs -u
grub-install ${DRIVE_ROOT}
update-grub
EOF
#grub-mkconfig -o /boot/grub/grub.cfg
chroot /tmp/mnt/root /chroot.sh;