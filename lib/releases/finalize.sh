#!/bin/bash
# Final cleanup stage (runs after final Debian release upgrade)

finalize() {
    log "=== Starting final cleanup stage ==="

    slim_system
    apt_cleanup
    clear_state_marker

    log "=== Upgrade complete ==="
}
