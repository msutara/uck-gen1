#!/bin/bash
# Buster → Bullseye upgrade stage

buster() {
    log "=== Starting Buster upgrade stage ==="

    write_sources_list "deb https://deb.debian.org/debian/ buster main contrib non-free
deb https://deb.debian.org/debian/ buster-updates main contrib non-free
deb https://deb.debian.org/debian-security/ buster/updates main contrib non-free"

    apt_upgrade
    apt_cleanup
    set_next_state "bullseye"
    safe_reboot
}
