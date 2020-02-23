How to run this?



wget https://raw.githubusercontent.com/egofelix/installer/master/installer.sh && chmod +x installer.sh && ./installer.sh --crypt --hostname newhost --home /dev/sdb --opt /dev/sdc --srv /dev/sdd --usr /dev/sde --var /dev/sdf


or


wget https://raw.githubusercontent.com/egofelix/installer/master/installer.sh && chmod +x installer.sh && ./installer.sh --crypt --hostname newhost.egofelix.de --srv /dev/sdc --srv-fs btrfs --var /dev/sdb


or with full

wget https://raw.githubusercontent.com/egofelix/installer/master/installer.sh && chmod +x installer.sh && ./installer.sh --crypt --fs btrfs --hostname newhost --home /dev/sdb --opt /dev/sdc --srv /dev/sdd --usr /dev/sde --var /dev/sdf



after install the boot password is test1234

you can change this with the following command:
cryptsetup luksChangeKey /dev/sda3
