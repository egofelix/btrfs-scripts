How to run this?

wget -O /tmp/installer.sh https://raw.githubusercontent.com/egofelix/installer/master/installer.sh && chmod +x /tmp/installer.sh && /tmp/installer.sh --hostname newhost

after install the boot password is test1234

you can change this with the following command:
cryptsetup luksChangeKey /dev/sda3
