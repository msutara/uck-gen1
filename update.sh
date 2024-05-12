#!/bin/bash

trap ctrl_c INT
function ctrl_c() {
  ubnt-systool reset2defaults
}

if [ `head -1 /etc/apt/sources.list | cut -d' ' -f3` == "jessie" ]; then
  if [ `cat /etc/apt/sources.list | egrep "^deb|^#" | wc -l` -le 4 ]; then
    echo "# jessie" >> /etc/apt/sources.list
  fi
fi

lsb_release -a

DEBIAN_FRONTEND=noninteractive
echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

state="`tail -1 /etc/apt/sources.list | cut -d' ' -f2 | egrep -v 'http'`"

#
# JESSIE
#
jessie () {

rm -rfv /etc/apt/sources.list.d/*

sudo dpkg -P unifi

sudo apt-get install debian-archive-keyring
sudo apt-key update

sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 112695A0E562B32A
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 648ACFD622F3D138
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0E98404D386FA1D9

systemctl disable cloudkey-webui
systemctl disable ubnt-freeradius-setup
systemctl disable ubnt-unifi-setup
systemctl disable ubnt-systemhub

systemctl disable nginx
systemctl disable php5-fpm

cat << EOF > /etc/apt/sources.list
deb https://archive.debian.org/debian/ jessie main contrib non-free
deb https://archive.debian.org/debian-security/ jessie/updates main contrib non-free
EOF

sudo apt-get -qy update
sudo apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade
sudo apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" dist-upgrade 

echo "# stretch" >> /etc/apt/sources.list

reboot
}

#
# STRETCH
#
stretch () {

cat << EOF > /etc/apt/sources.list
deb https://archive.debian.org/debian/ stretch main contrib non-free
deb https://archive.debian.org/debian-security/ stretch/updates main contrib non-free
EOF

sudo apt-get -qy update
sudo apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade
sudo apt-get -qy --purge autoremove
sudo apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" dist-upgrade 

echo "# buster" >> /etc/apt/sources.list

sudo apt-get full-upgrade
sudo apt-get -qy --purge autoremove
sudo apt-get -qy autoclean
reboot
}

#
# BUSTER
#
buster () {

cat << EOF > /etc/apt/sources.list
deb https://deb.debian.org/debian/ buster main contrib non-free
deb https://deb.debian.org/debian/ buster-updates main contrib non-free
deb https://deb.debian.org/debian-security/ buster/updates main contrib non-free
EOF

sudo apt-get -qy update
sudo apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade
sudo apt-get -qy --purge autoremove
sudo apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" dist-upgrade 

echo "# bullseye" >> /etc/apt/sources.list

sudo apt-get full-upgrade
sudo apt-get -qy --purge autoremove
sudo apt-get -qy autoclean
reboot
}

#
# BULLSEYE
#
bullseye () {

cat << EOF > /etc/apt/sources.list
deb https://deb.debian.org/debian/ bullseye main contrib non-free
deb https://deb.debian.org/debian/ bullseye-updates main contrib non-free
deb https://deb.debian.org/debian-security/ bullseye-security main contrib non-free
deb https://deb.debian.org/debian-security/ bullseye-security/updates main contrib non-free
EOF

sudo apt-get -qy update
sudo apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade
sudo apt-get -qy --purge autoremove
sudo apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" dist-upgrade 

sudo apt-get full-upgrade
sudo apt-get -qy --purge autoremove
sudo apt-get -qy autoclean
reboot
}

if [ -z $state ]; then
  echo "Latest tested version installed..."
else
  echo "Starting with $state"
  $state
fi
