#!/bin/bash
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
pacman -Qqe | xargs pacman -S --noconfirm
EOF
chmod +x /tmp/mnt/root/chroot.sh;
chroot /tmp/mnt/root /chroot.sh;