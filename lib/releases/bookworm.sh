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

    # Bookworm defaults to PermitRootLogin prohibit-password; --force-confnew
    # overwrites sshd_config, locking out headless root-password access.
    log "Ensuring root SSH password login remains enabled..."
    run sed -i -E 's/^[[:blank:]]*#?[[:blank:]]*PermitRootLogin[[:blank:]].*/PermitRootLogin yes/' /etc/ssh/sshd_config
    # Append directive if no PermitRootLogin line exists at all
    run sh -c "grep -Eq '^[[:blank:]]*PermitRootLogin[[:blank:]]+' /etc/ssh/sshd_config || echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config"

    # Detect SSH service unit name (ssh or sshd) and reload safely.
    local ssh_unit=""
    ssh_unit="$(detect_ssh_unit)"
    if [[ -n "$ssh_unit" ]]; then
        run systemctl reload-or-restart "$ssh_unit"
    else
        log_error "No ssh/sshd systemd unit found; skipping SSH reload."
    fi

    transition_state "finalize"
    log "=== Bookworm upgrade complete; final cleanup scheduled ==="
    safe_reboot
}
