#!/bin/bash
# Jessie → Stretch upgrade stage
# This is the initial stage that also removes Ubiquiti packages and services

jessie() {
    log "=== Starting Jessie upgrade stage ==="

    run_optional find /etc/apt/sources.list.d -mindepth 1 -maxdepth 1 -exec rm -rfv {} +

    log "Removing UniFi packages..."
    run_optional dpkg -P unifi

    log "Updating archive keyrings..."
    run apt-get install -y debian-archive-keyring
    run apt-key update

    run apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 112695A0E562B32A
    run apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 648ACFD622F3D138
    run apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0E98404D386FA1D9

    log "Disabling Ubiquiti services..."
    run_optional systemctl disable cloudkey-webui
    run_optional systemctl disable ubnt-freeradius-setup
    run_optional systemctl disable ubnt-unifi-setup
    run_optional systemctl disable ubnt-systemhub
    run_optional systemctl disable nginx
    run_optional systemctl disable php5-fpm

    write_sources_list "deb https://archive.debian.org/debian/ jessie main contrib non-free
deb https://archive.debian.org/debian-security/ jessie/updates main contrib non-free"

    apt_upgrade
    set_next_state "stretch"
    safe_reboot
}
