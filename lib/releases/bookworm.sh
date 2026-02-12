#!/bin/bash
# Bookworm — final upgrade stage (Debian 12)

bookworm() {
    log "=== Starting Bookworm upgrade stage ==="

    write_sources_list "deb https://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb https://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb https://deb.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware"

    apt_upgrade
    apt_cleanup

    log "=== Upgrade to Bookworm (Debian 12) complete ==="
    # No set_next_state — this is the final target
}
