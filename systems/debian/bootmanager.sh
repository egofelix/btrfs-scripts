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
DEBIAN_FRONTEND=noninteractive apt-get -yq install linux-image-amd64 grub-efi efibootmgr
EOF
    else
      cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
DEBIAN_FRONTEND=noninteractive apt-get -yq install linux-image-amd64 grub
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
DEBIAN_FRONTEND=noninteractive apt-get -yq install cryptsetup
EOF
  chroot /tmp/mnt/root /chroot.sh;

  # Append cryptsystem in crypttab
  if [[ -z $(cat /tmp/mnt/root/etc/crypttab | grep 'cryptsystem ') ]]; then
    echo cryptsystem PARTLABEL=system none luks > /tmp/mnt/root/etc/crypttab
  fi;

fi;

# Install Grub
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
update-initramfs -u
grub-install ${DRIVE_ROOT}
grub-mkconfig -o /boot/grub/grub.cfg
EOF
chroot /tmp/mnt/root /chroot.sh;