#!/bin/bash
# Bullseye → Bookworm upgrade stage

bullseye() {
    log "=== Starting Bullseye upgrade stage ==="

    write_sources_list "deb https://deb.debian.org/debian/ bullseye main contrib non-free
deb https://deb.debian.org/debian/ bullseye-updates main contrib non-free
deb https://deb.debian.org/debian-security/ bullseye-security main contrib non-free"

    apt_upgrade
    apt_cleanup
    set_next_state "bookworm"
    safe_reboot
}
