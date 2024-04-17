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

DEBIAN_FRONTEND=noninteractive
echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

state="`tail -1 /etc/apt/sources.list | cut -d' ' -f2 | egrep -v 'http'`"

#
# STRETCH
#
stretch () {
rm -rfv /etc/apt/sources.list.d/*
lsb_release -a
apt -qy purge  cloudkey-webui  ubnt-archive-keyring  ubnt-crash-report  ubnt-freeradius-setup  ubnt-mtk-initramfs  ubnt-unifi-setup  ubnt-systemhub
apt -qy purge  nginx-light  libnginx-mod-http-echo  
cat << EOF > /etc/apt/sources.list
deb https://archive.debian.org/debian/ stretch main contrib non-free
deb https://archive.debian.org/debian-security/ stretch/updates main contrib non-free
EOF
apt-get -qy update
apt-get install debian-archive-keyring
apt-key update
apt-get -qy update
apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade
apt-get -qy --purge autoremove
apt-get -qy dist-upgrade 
echo "# buster" >> /etc/apt/sources.list
reboot
DEBIAN_FRONTEND=noninteractive
echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
apt -qy purge  nginx-common  
apt -qy purge  postgresql  postgresql-client  postgresql-common  postgresql-contrib
apt -qy purge  unifi  mongodb-clients  mongodb-server
apt-get -qy autoclean
}

if [ -z $state ]; then
  echo "Latest tested version installed..."
else
  echo "Starting with $state"
  $state
fi
