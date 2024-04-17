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
    echo "# jessie" >> /etc/apt/sources.list
  fi
fi

DEBIAN_FRONTEND=noninteractive
state="`tail -1 /etc/apt/sources.list | cut -d' ' -f2 | egrep -v 'http'`"

#
# refresh jessie aptitude
#
jessie () {
rm -rfv /etc/apt/sources.list.d/*
dpkg-reconfigure dash #Select NO Here
lsb_release -a
cat << EOF > /etc/apt/sources.list
deb https://archive.debian.org/debian/ jessie main contrib non-free
deb https://archive.debian.org/debian-security/ jessie/updates main contrib non-free
EOF
apt-key update
apt update
apt -y upgrade
echo "# stretch" >> /etc/apt/sources.list
apt-get -y --purge autoremove
apt -y purge cloudkey-webui  cloudkey-mtk7623-base-files  
apt -y purge ubnt-archive-keyring  ubnt-crash-report  ubnt-freeradius-setup  ubnt-mtk-initramfs  ubnt-unifi-setup  unifi
apt -y purge mongodb-clients  mongodb-server
apt -y purge postgresql  postgresql-client  postgresql-common  postgresql-contrib
apt -y purge nginx-common  nginx-light  libnginx-mod-http-echo  
reboot
}

#
# get stretch aptitude
#
stretch () {
lsb_release -a
cat << EOF > /etc/apt/sources.list
deb https://archive.debian.org/debian/ stretch main contrib non-free
deb https://archive.debian.org/debian-security/ stretch/updates main contrib non-free
EOF
apt-key update
apt update
apt -y upgrade
apt -y full-upgrade
echo "# buster" >> /etc/apt/sources.list
reboot
apt-get -y --purge autoremove
}

if [ -z $state ]; then
  echo "Latest tested version installed..."
else
  echo "Starting with $state"
  $state
fi
