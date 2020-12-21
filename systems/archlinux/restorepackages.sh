#!/bin/bash
cat > /tmp/mnt/root/chroot.sh <<- EOF
#!/bin/bash
for package in \$(pacman -Qqe);
do
  echo Reinstalling \$package;
  pacman -S --noconfirm \$package;
done;
EOF
chmod +x /tmp/mnt/root/chroot.sh;
chroot /tmp/mnt/root /chroot.sh &> /dev/null;