#!/bin/bash
# Bullseye — final upgrade stage (Debian 11)
# Bookworm (Debian 12) is not supported on UCK Gen1 due to AUFS/usrmerge
# incompatibility. See docs/BOOKWORM-FINDINGS.md for details.

bullseye() {
    log "=== Starting Bullseye upgrade stage ==="

    write_sources_list "deb https://deb.debian.org/debian/ bullseye main contrib non-free
deb https://deb.debian.org/debian/ bullseye-updates main contrib non-free
deb https://deb.debian.org/debian-security/ bullseye-security main contrib non-free"
    set_next_state "bullseye"

    apt_upgrade
    apt_cleanup
    transition_state "finalize"
    safe_reboot
}
