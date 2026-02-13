#!/bin/bash
# Stretch → Buster upgrade stage

stretch() {
    log "=== Starting Stretch upgrade stage ==="

    write_sources_list "deb https://archive.debian.org/debian/ stretch main contrib non-free
deb https://archive.debian.org/debian-security/ stretch/updates main contrib non-free"
    set_next_state "stretch"

    apt_upgrade
    transition_state "buster"
    safe_reboot
}
