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
pacman -Sy --noconfirm linux linux-firmware grub efibootmgr btrfs-progs openssh cryptsetup
EOF
else
	cat >> /tmp/mnt/root/chroot.sh <<- EOF
# install grub
pacman -Sy --noconfirm linux linux-firmware grub efibootmgr btrfs-progs openssh
EOF
fi;

# Run script
chmod +x /tmp/mnt/root/chroot.sh
chroot /tmp/mnt/root /chroot.sh &> /dev/null

# Remove unneccesarry hooks from mkinitcpio.conf
#HOOKS="HOOKS=($(source /etc/mkinitcpio.conf && HOOKS=(${HOOKS[@]/archiso_shutdown}) && HOOKS=(${HOOKS[@]/archiso_pxe_common}) && HOOKS=(${HOOKS[@]/archiso_pxe_nbd}) && HOOKS=(${HOOKS[@]/archiso_pxe_nfs}) && HOOKS=(${HOOKS[@]/archiso_pxe_http}) && HOOKS=(${HOOKS[@]/archiso_kms}) && HOOKS=(${HOOKS[@]/archiso_loop_mnt}) && HOOKS=(${HOOKS[@]/archiso}) && HOOKS=(${HOOKS[@]/archiso}) && HOOKS=(${HOOKS[@]/memdisk}) && echo ${HOOKS[@]} | xargs echo -n))"
#sed -i "s/HOOKS=.*/${HOOKS}/g" /tmp/mnt/root/etc/mkinitcpio.conf

# Add usr hook to mkinitcpio.conf if usr is on a subvolume
if [[ ${SUBVOLUMES} == *"usr"* ]]; then
	HOOKS="HOOKS=($(source /tmp/mnt/root/etc/mkinitcpio.conf && if [[ ${HOOKS[@]} != *"usr"* ]]; then HOOKS+=(usr); fi && echo ${HOOKS[@]} | xargs echo -n))"
	sed -i "s/HOOKS=.*/${HOOKS}/g" /tmp/mnt/root/etc/mkinitcpio.conf
fi;

# Setup crypto
if isTrue "${CRYPTED}"; then
	echo cryptsystem PARTLABEL=system none luks > /tmp/mnt/root/etc/crypttab
	
	# Add hooks for cryptsetup to mkinitcpio.conf
	HOOKS="HOOKS=($(source /tmp/mnt/root/etc/mkinitcpio.conf && if [[ ${HOOKS[@]} != *"keyboard"* ]]; then HOOKS+=(keyboard); fi && if [[ ${HOOKS[@]} != *"keymap"* ]]; then HOOKS+=(keymap); fi && if [[ ${HOOKS[@]} != *"encrypt"* ]]; then HOOKS+=(encrypt); fi && echo ${HOOKS[@]} | xargs echo -n))"
	sed -i "s/HOOKS=.*/${HOOKS}/g" /tmp/mnt/root/etc/mkinitcpio.conf
	
	# Setup Grub for Cryptsetup
	echo "GRUB_ENABLE_CRYPTODISK=y" >> /tmp/mnt/root/etc/default/grub
	REPLACEMENT='GRUB_CMDLINE_LINUX="cryptdevice=PARTLABEL=system:cryptsystem"'
	
	sed -i "s;GRUB_CMDLINE_LINUX=.*;${REPLACEMENT};g" /tmp/mnt/root/etc/default/grub
fi;

# Setup locale
sed -i '/de_DE.UTF-8/s/^#//' /tmp/mnt/root/etc/locale.gen
sed -i '/en_US.UTF-8/s/^#//' /tmp/mnt/root/etc/locale.gen
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
locale-gen
EOF
chroot /tmp/mnt/root /chroot.sh &> /dev/null

# Setup sshd
sed -i 's/^#PermitRootLogin .*/PermitRootLogin yes/' /tmp/mnt/root/etc/ssh/sshd_config
sed -i 's/^PermitRootLogin .*/PermitRootLogin yes/' /tmp/mnt/root/etc/ssh/sshd_config

# Install grub
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
mkinitcpio -P
grub-install
grub-mkconfig -o /boot/grub/grub.cfg
EOF
chroot /tmp/mnt/root /chroot.sh &> /dev/null

# Setup Network
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable sshd
EOF
chroot /tmp/mnt/root /chroot.sh &> /dev/null
cat > /tmp/mnt/root/etc/systemd/network/en.network <<- EOM
[Match]
Name=en*

[Network]
DHCP=yes
EOM
cat > /tmp/mnt/root/etc/systemd/network/eth.network <<- EOM
[Match]
Name=eth*

[Network]
DHCP=yes
EOM

# Resotre resolv.conf
rm -f /tmp/mnt/root/etc/resolv.conf
ln -s /run/systemd/resolve/stub-resolv.conf /tmp/mnt/root/etc/resolv.conf
rm -f /tmp/mnt/root/etc/network/interfaces
rm -f /tmp/mnt/root/etc/network/interfaces.d/*
