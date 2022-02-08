#!/bin/sh
# Set current Time
sudo date -s "$(curl -s --head http://google.com.au | grep ^Date: | sed 's/Date: //g')"

# Stop unattended Upgrades and wait to continue
sudo /etc/init.d/unattended-upgrades stop
i=0 
tput sc 
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 ; do
     case $(($i % 4)) in
         0 ) j="-" ;;
         1 ) j="\\" ;;
         2 ) j="|" ;;
         3 ) j="/" ;;
     esac
     tput rc
     echo -en "\r[$j] Waiting for unattended Upgrade to finish..." 
     sleep 0.5
     ((i=i+1)) 
done

# Install necessary Packages and ZFS
sudo apt update
sudo apt install -y samba zfs-dkms cockpit

# Start ZFS Module before reboot
sudo /sbin/modprobe zfs 

# Set first Samba Password
sudo smbpasswd -x ubuntu
(echo NasBeery2020; echo NasBeery2020) |sudo smbpasswd -a ubuntu

# Get ZFS Addon for Cockpit
git clone https://github.com/optimans/cockpit-zfs-manager.git
sudo cp -r cockpit-zfs-manager/zfs /usr/share/cockpit

# Install zfs-auto-snapshot and change Retention from 24 to 48h and 12 to 3 Month for more sense of usage
sudo apt install -y zfs-auto-snapshot
sudo sed -i 's/24/48/g' /etc/cron.hourly/zfs-auto-snapshot
sudo sed -i 's/12/3/g' /etc/cron.monthly/zfs-auto-snapshot

# change hostname
sudo sed -i 's/ubuntu/nasbeery/g' /etc/hostname

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
      sudo zpool create -f -o autoexpand=on -o ashift=12 tank mirror sda sdb;;
   255) echo "[ESC] key pressed >> EXIT" &&  exit;;
esac

# create Share with Compression, Samba share has to be in smb.conf to work with Snapshots later
sudo zfs create -o compression=lz4 tank/share
sudo chmod -R 770 /tank
sudo chown -R ubuntu:root /tank

# check Mirror to be online, otherwise Power Indicator like LED or Buzzer
echo -en "PATH="/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"\n*/1 * * * * root echo 14 > /sys/class/gpio/export 2> /dev/null;echo out > /sys/class/gpio/gpio14/direction ; zpool import -fa -d /dev/ > /dev/null; zpool list| grep -q ONLINE; echo \$? > /sys/class/gpio/gpio14/value\n" | sudo tee  "/etc/cron.d/raidled"

# Add to smb.conf how ZFS Snapshots

echo -en "[share]\ncomment = Main Share\npath = /tank/share\nread only = No\nvfs objects = shadow_copy2\nshadow: snapdir = .zfs/snapshot\nshadow: sort = desc\nshadow: format = -%Y-%m-%d-%H%M\nshadow: snapprefix = ^zfs-auto-snap_\(frequent\)\{0,1\}\(hourly\)\{0,1\}\(daily\)\{0,1\}\(monthly\)\{0,1\}\nshadow: delimiter = -20\n" | sudo tee -a "/etc/samba/smb.conf"


# Change password for Samba and Terminal
while [[ "$PASSWORD" != "$PASSWORD_REPEAT" || ${#PASSWORD} -lt 8 ]]; do
  PASSWORD=$(whiptail --backtitle "NASBEERY SETUP" --title "Set password!" --passwordbox "${PASSWORD_invalid_message}Please set a password for Terminal, Samba and Backupwireless\n(At least 8 characters!):" 10 75 3>&1 1>&2 2>&3)
  PASSWORD_REPEAT=$(whiptail --backtitle "NASBEERY SETUP" --title "Set password!" --passwordbox "Please repeat the Password:" 10 70 3>&1 1>&2 2>&3)
  PASSWORD_invalid_message="ERROR: Password is too short, or not matching! \n\n"
done

echo "ubuntu:$PASSWORD" | sudo chpasswd
(echo "$PASSWORD"; echo "$PASSWORD") | sudo smbpasswd -a ubuntu


sudo reboot
