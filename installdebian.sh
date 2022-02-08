#!/bin/sh
apt update
apt install -y linux-headers-$(uname -r)
#apt install -y zfs-dkms cockpit 
apt install -y cockpit samba
/sbin/modprobe zfs


# Get ZFS Addon for Cockpit
git clone https://github.com/optimans/cockpit-zfs-manager.git
 cp -r cockpit-zfs-manager/zfs /usr/share/cockpit

# Install zfs-auto-snapshot and change Retention from 24 to 48h and 12 to 3 Month for more sense of usage
 apt install -y zfs-auto-snapshot
 sed -i 's/24/48/g' /etc/cron.hourly/zfs-auto-snapshot
 sed -i 's/12/3/g' /etc/cron.monthly/zfs-auto-snapshot

# change hostname
hostnamectl set-hostname nasbeery.bashclub.lan
sed -i 's/localhost/nasbeery.bashclub.lan   nasbeery/g' /etc/hosts

# ask for deletion of existing data and create Mirror 
whiptail --title "Possible data loss!" \
--backtitle "NASBEERY SETUP" \
--yes-button "PRESERVE DATA" \
--no-button  "FORMAT DISKS!" \
--yesno "Would you like to preserve you existing ZFS data from a previous installation?" 10 75

# Get exit status
# 0 means user hit [yes] button.
# 1 means user hit [no] button.
# 255 means user hit [Esc] key.
response=$?
case $response in
   0) echo "Your ZFS Data will be preserved";;
   1) echo "Existing data on the drives will be deleted..."
       zpool create -f -o autoexpand=on -o ashift=12 tank mirror sda sdb;;
   255) echo "[ESC] key pressed >> EXIT" &&  exit;;
esac

# create Share with Compression, Samba share has to be in smb.conf to work with Snapshots later
 zfs create -o compression=lz4 tank/share
 chmod -R 770 /tank
 chown -R root:root /tank

# check Mirror to be online, otherwise Power Indicator like LED or Buzzer
echo -e "PATH="/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"\n*/1 * * * * root echo 14 > /sys/class/gpio/export 2> /dev/null;echo out > /sys/class/gpio/gpio14/direction ; zpool import -fa -d /dev/ > /dev/null; zpool list| grep -q ONLINE; echo \$? > /sys/class/gpio/gpio14/value" |  tee  "/etc/cron.d/raidled"

# Add to smb.conf how ZFS Snapshots

echo -en "[share]\ncomment = Main Share\npath = /tank/share\nread only = No\nvfs objects = shadow_copy2\nshadow: snapdir = .zfs/snapshot\nshadow: sort = desc\nshadow: format = -%Y-%m-%d-%H%M\nshadow: snapprefix = ^zfs-auto-snap_\(frequent\)\{0,1\}\(hourly\)\{0,1\}\(daily\)\{0,1\}\(monthly\)\{0,1\}\nshadow: delimiter = -20\n" |  tee -a "/etc/samba/smb.conf"


# Change password for Samba and Terminal
while [[ "$PASSWORD" != "$PASSWORD_REPEAT" || ${#PASSWORD} -lt 8 ]]; do
  PASSWORD=$(whiptail --backtitle "NASBEERY SETUP" --title "Set password!" --passwordbox "${PASSWORD_invalid_message}Please set a password for Terminal, Samba and Backupwireless\n(At least 8 characters!):" 10 75 3>&1 1>&2 2>&3)
  PASSWORD_REPEAT=$(whiptail --backtitle "NASBEERY SETUP" --title "Set password!" --passwordbox "Please repeat the Password:" 10 70 3>&1 1>&2 2>&3)
  PASSWORD_invalid_message="ERROR: Password is too short, or not matching! \n\n"
done

echo "root:$PASSWORD" |  chpasswd
(echo "$PASSWORD"; echo "$PASSWORD") |  smbpasswd -a root

### here we go with ispconfig later
exit

zfs create -o mountpoint=/var/www tank/ispwww
zfs create -o mountpoint=/var/backup tank/ispbackup
zfs create -o mountpoint=/var/lib/mysql tank/ispmysql
wget -O - https://get.ispconfig.org | sh -s -- --help
#Rar is not available, so we go with Midnight Commander:)
sed -i 's/rar/mc/g' /tmp/ispconfig-ai/lib/os/class.ISPConfigDebianOS.inc.php
php /tmp/ispconfig-ai/ispconfig.ai.php --lang=en --use-php=7.4,8.1 --no-mail --no-dns --no-firewall --no-roundcube --no-quota --unattended-upgrades --i-know-what-i-am-doing
