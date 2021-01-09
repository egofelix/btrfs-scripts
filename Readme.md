How to run this?

To install:

pacman -Sy --noconfirm git

git clone https://github.com/egofelix/btrfs-scripts.git

btrfs-scripts/installer.sh



The default cryptsetup password is: test1234

The default login is: root / root



To restore:



after install the boot password is test1234

you can change this with the following command:
cryptsetup luksChangeKey /dev/sda4
