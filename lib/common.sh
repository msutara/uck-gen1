#!/bin/bash
# Common functions for UCK Gen1 Debian upgrade
# Sourced by bin/uck-upgrade and lib/releases/*.sh

readonly UCK_LOG_FILE="/var/log/uck-upgrade.log"
readonly UCK_SOURCES_LIST="/etc/apt/sources.list"
# shellcheck disable=SC2034  # used by bin/uck-upgrade which sources this file
readonly UCK_VERSION="2.0.0"

DRY_RUN=false

# --- Logging ---

log() {
    local msg
    msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg"
    if [[ "$DRY_RUN" == false ]]; then
        echo "$msg" >> "$UCK_LOG_FILE" 2>/dev/null
    fi
}

log_error() {
    log "ERROR: $*" >&2
}

# --- Command execution (dry-run aware) ---

run() {
    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY-RUN] Would run: $*"
        return 0
    fi
    log "Running: $*"
    "$@"
}

run_optional() {
    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY-RUN] Would run (optional): $*"
        return 0
    fi
    log "Running (optional): $*"
    "$@" || {
        log "Optional command failed; continuing: $*"
        return 0
    }
}

# --- APT helpers ---

apt_upgrade() {
    run sudo apt-get -qy update
    run sudo apt-get -qy -o "Dpkg::Options::=--force-confnew" upgrade
    run sudo apt-get -qy -o "Dpkg::Options::=--force-confnew" dist-upgrade
}

apt_cleanup() {
    run sudo apt-get -qy --purge autoremove
    run sudo apt-get -qy autoclean
}

# --- State management ---

write_sources_list() {
    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY-RUN] Would write to $UCK_SOURCES_LIST:"
        log "$1"
        return 0
    fi
    cat <<< "$1" > "$UCK_SOURCES_LIST"
}

set_next_state() {
    local next_release="$1"
    log "Setting next upgrade state: $next_release"
    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY-RUN] Would append '# $next_release' to $UCK_SOURCES_LIST"
    else
        echo "# $next_release" >> "$UCK_SOURCES_LIST"
    fi
}

get_current_state() {
    local last_line=""
    last_line="$(tail -1 "$UCK_SOURCES_LIST" 2>/dev/null || true)"

    if [[ "$last_line" =~ ^#[[:space:]]*(jessie|stretch|buster|bullseye|bookworm)$ ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
    return 0
}

# --- Safety checks ---

check_root() {
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
}

check_network() {
    if ! ping -c 1 -W 5 deb.debian.org &>/dev/null &&
       ! ping -c 1 -W 5 archive.debian.org &>/dev/null; then
        log_error "Cannot reach Debian mirrors — check network connectivity"
        exit 1
    fi
}

# --- Reboot ---

safe_reboot() {
    log "Stage complete. Rebooting to continue upgrade..."
    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY-RUN] Would reboot now"
    else
        reboot
    fi
}
