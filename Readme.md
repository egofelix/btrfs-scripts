# btrfs-scripts

### What are btrfs-scripts? 
btrfs-scripts is a set of bash-scripts that helps you setting up and backing up an arch-linux-system on btrfs.

### Scripts in this repository
 - installer.sh
 - receiver.sh
 - snapshot.sh
 - ssh_backup.sh
 - ssh_restore.sh

#### Quickstart for Restore
if [[ ! -d ~/btrfs-scripts ]]; then git clone https://github.com/egofelix/btrfs-scripts.git ~/btrfs-scripts; else git -C ~/btrfs-scripts pull; fi;
~/btrfs-scripts/sbin/backup-client --remote ssh://myuser@myserver restore

#### How to install a base system
To install a base-system you have to boot the live iso of arch-linux.
From there you will install git and clone this repository.
After that you can call backup-client and it will guide you through the installation.
This repository will be automatically cloned into /opt/btrfs-scripts/ on your new system.

In short:

`pacman -Sy --noconfirm git`

`git clone https://github.com/egofelix/btrfs-scripts.git`

For restore
`btrfs-scripts/sbin/backup-client --remote ssh://myuser@myserver restore`

For fresh install:
`btrfs-scripts/sbin/backup-client bootstrap --distro debian`

#### How do I create a snapshot of my system?
To create snapshots of all btrfs-volumes simply run `/opt/btrfs-scripts/sbin/backup-client create-snapshot` as root.
Volumes starting with `@` will be ignored from this script.
The snapshots will be created at the `@snapshots` volume (Defaults to `/.snapshots`)

#### How do i send snapshots to a different server?
You can send backups to a specific server by running `/opt/btrfs-scripts/sbin/backup-client --remote ssh://user@server:port/ send-snapshots`

#### How to setup a backup-server?
Btrfs supports sending incremental backups to other destinations. To make use of this you can call the setup a system which will receive these.

In this example we will have two computers:
- `mymachine` - this is the machine which we want to backup
- `backupserver` - this is the machine which should receive the snapshots

The receiving system must have a btrfs volume, must be running ssh and needs sudo installed, as well as a set of this scripts.

We assume you have a subvolume `@backups` mountet at `/.backups` and have this scripts present at `/opt/btrfs-scripts`.

First you need to create a user which should be used for `mymachine` to connect `backupserver`. If you want to backup multiple machines then create a user for each machine. In our example we will keep it simple and call the user `mymachinebackup`.

After you have created the user also create a folder in `/.backups` where the snapshots of this user should be stored. For easyness we call the folder `/.backups/mymachine` here.

Then you have to create the `authorized_keys` file for the user `mymachinebackup`.
You will add the ssh-public-ed25519-key `/etc/ssh/ssh_host_ed25519_key.pub` from `mymachine` to it. Then you have to pretend this key from executing other command by pretending it with `command="/usr/bin/sudo -n /opt/btrfs-scripts/receiver.sh --target \"/.backups/mymachine/\" --command \"${SSH_ORIGINAL_COMMAND}\""`. This tells ssh that the user `mymachinebackup` should call the receiver-script automatically, which then handles all other stuff.

Also you have to allow the user `mymachinebackup` to call `sudo /opt/btrfs-scripts/receiver.sh` without any password by editing sudoers (use `visudo`).

Thats all and the backup server should be ready!

You can now send backups to this server from `mymachine` by calling `/opt/btrfs-scripts/ssh_backup.sh --target ssh://mymachinebackup@backupserver/`


### Default values
Default login: `root`

Default password: `root`

Default passphrase to unlock luks: `test1234`

To change the luks passphrase you can call `cryptsetup luksChangeKey /dev/sda4`.