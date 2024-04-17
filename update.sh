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
  apt update
  apt -y upgrade
  echo "# stretch" >> /etc/apt/sources.list
  apt -y autoremove
  reboot
}


if [ -z $state ]; then
  echo "Latest tested version installed..."
else
  echo "Starting with $state"
  $state
fi
