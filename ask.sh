#!/bin/bash
dialog --title "Would you like to preserve you existing ZFS Data from a previous Installation?" \
--backtitle "Your Disks shall be formated!!!" \
--yesno "Are you sure you want to preserve your ZFS Data?" 7 60

# Get exit status
# 0 means user hit [yes] button.
# 1 means user hit [no] button.
# 255 means user hit [Esc] key.
response=$?
case $response in
   0) echo Your ZFS Data will be preserved;;
   1) sudo zpool create -f -o autoexpand=on -o ashift=12 tank mirror sda sdb;; 
   255) exit;;
esac


data=$(tempfile 2>/dev/null)

# trap it
trap "rm -f $data" 0 1 2 5 15

# get password
sudo dialog --title "Please set a Password for Terminal, Samba and Wireless Backup" \
--clear \
--passwordbox "Enter your password" 10 30 2> $data

ret=$?

# make decision
case $ret in
  0)
	  echo "ubuntu:$(cat $data)" | sudo chpasswd
	  (echo "$(cat $data)"; echo "$(cat $data)") | sudo smbpasswd -a ubuntu
	  echo "Your Password for Terminal, Samba and Backupwireless is" && cat "$data";;
  1)
    echo "Cancel pressed.";;
  255)
    [ -s $data ] &&  cat $data || echo "ESC pressed."&&exit;;
esac
