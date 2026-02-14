#!/bin/bash
# Bookworm — final upgrade stage (Debian 12)

bookworm() {
    log "=== Starting Bookworm upgrade stage ==="

    # Prevent usrmerge failure: /lib/modules may be a busy AUFS mount
    run_optional umount /lib/modules

    write_sources_list "deb https://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb https://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb https://deb.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware"

    # Keep a resumable marker for this stage in case interruption occurs.
    set_next_state "bookworm"

    apt_upgrade
    transition_state "finalize"
    log "=== Bookworm upgrade complete; final cleanup scheduled ==="
    safe_reboot
}
