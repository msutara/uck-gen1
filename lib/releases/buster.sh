#!/bin/bash
# Buster → Bullseye upgrade stage

buster() {
    log "=== Starting Buster upgrade stage ==="

    write_sources_list "deb https://archive.debian.org/debian/ buster main contrib non-free
deb https://archive.debian.org/debian-security/ buster/updates main contrib non-free"
    set_next_state "buster"

    apt_upgrade
    apt_cleanup
    transition_state "bullseye"
    safe_reboot
}
