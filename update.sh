#!/bin/bash

trap cleanup EXIT
function cleanup {
	rm -f upgrade.list
}

trap ctrl_c INT
function ctrl_c() {
	rm -f upgrade.list
	ubnt-systool reset2defaults
}

if [ `head -1 /etc/apt/sources.list | cut -d' ' -f3` == "jessie" ]; then
  if [ `cat /etc/apt/sources.list | egrep "^deb|^#" | wc -l` -le 4 ]; then
    echo "# stretch" >> /etc/apt/sources.list
  fi
fi

rm -rfv /etc/apt/sources.list.d/*
lsb_release -a

DEBIAN_FRONTEND=noninteractive
echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

apt-get -qy --purge autoremove
apt-get -qy autoclean

state="`tail -1 /etc/apt/sources.list | cut -d' ' -f2 | egrep -v 'http'`"

#
# STRETCH
#
stretch () {

apt -qy purge  ubnt-freeradius-setup  libfreeradius2  freeradius-utils  freeradius-ldap  freeradius-common  freeradius

apt-get install debian-archive-keyring
apt-key update
apt-get -qy update

cat << EOF > /etc/apt/sources.list
deb https://archive.debian.org/debian/ stretch main contrib non-free
deb https://archive.debian.org/debian-security/ stretch/updates main contrib non-free
EOF

apt-get -qy update
apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade
apt-get -qy --purge autoremove
apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" dist-upgrade 
echo "# buster" >> /etc/apt/sources.list
reboot
}

#
# BUSTER
#
buster () {

apt -qy purge  unifi
rm -rf /var/log/unifi/
apt -qy purge  cloudkey-webui  ubnt-archive-keyring  ubnt-crash-report  ubnt-unifi-setup  mongodb-clients

cat << EOF > /etc/apt/sources.list
deb https://deb.debian.org/debian/ buster main contrib non-free
deb https://deb.debian.org/debian/ buster-updates main contrib non-free
deb https://deb.debian.org/debian-security/ buster/updates main contrib non-free
EOF

apt-get -qy update
apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade
apt-get -qy --purge autoremove
apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" dist-upgrade 
echo "# bullseye" >> /etc/apt/sources.list
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

apt-get -qy update
apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade
apt-get -qy --purge autoremove
apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" dist-upgrade 
reboot
}

if [ -z $state ]; then
  echo "Latest tested version installed..."
else
  echo "Starting with $state"
  $state
fi
