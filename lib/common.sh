#!/bin/bash
# Common functions for UCK Gen1 Debian upgrade
# Sourced by bin/uck-upgrade and lib/releases/*.sh

readonly UCK_LOG_FILE="/var/log/uck-upgrade.log"
readonly UCK_SOURCES_LIST="/etc/apt/sources.list"
# shellcheck disable=SC2034  # used by bin/uck-upgrade which sources this file
readonly UCK_VERSION="2.0.0"

DRY_RUN=false
KEEP_PACKAGES=false

state_marker_line() {
    local release="$1"
    if [[ "$KEEP_PACKAGES" == true ]]; then
        echo "# $release keep-packages"
    else
        echo "# $release"
    fi
}

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
    run apt-get -qy update
    run apt-get -qy -o "Dpkg::Options::=--force-confnew" upgrade
    run apt-get -qy -o "Dpkg::Options::=--force-confnew" dist-upgrade
}

apt_cleanup() {
    run apt-get -qy --purge autoremove
    run apt-get -qy autoclean
}

slim_system() {
    if [[ "$KEEP_PACKAGES" == true ]]; then
        log "Keeping optional packages (--keep-packages set)."
        return 0
    fi

    log "Slim mode enabled: purging optional package set..."

    local patterns=(
        "unifi"
        "openjdk-*"
        "default-jre*"
        "mongodb*"
        "nginx*"
        "php*-fpm"
        "freeradius*"
        "cloudkey-webui"
        "ubnt-freeradius-setup"
        "ubnt-unifi-setup"
        "ubnt-systemhub"
    )
    local installed=()
    local pattern
    local pkg

    for pattern in "${patterns[@]}"; do
        while IFS= read -r pkg; do
            if [[ -n "$pkg" ]]; then
                installed+=("$pkg")
            fi
        done < <(dpkg-query -W -f='${binary:Package}\n' "$pattern" 2>/dev/null || true)
    done

    if [[ ${#installed[@]} -eq 0 ]]; then
        log "No optional packages found for purge."
        return 0
    fi

    mapfile -t installed < <(printf '%s\n' "${installed[@]}" | sort -u)

    log "Purging optional packages: ${installed[*]}"
    run apt-get -qy --purge remove "${installed[@]}"
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
    local marker
    marker="$(state_marker_line "$next_release")"
    log "Setting next upgrade state: $next_release"
    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY-RUN] Would append '$marker' to $UCK_SOURCES_LIST"
    else
        echo "$marker" >> "$UCK_SOURCES_LIST"
    fi
}

transition_state() {
    local next_release="$1"
    local marker
    local last_line=""
    local tmp_file=""

    marker="$(state_marker_line "$next_release")"
    log "Transitioning state marker to: $next_release"

    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY-RUN] Would replace trailing state marker with '$marker' in $UCK_SOURCES_LIST"
        return 0
    fi

    last_line="$(tail -1 "$UCK_SOURCES_LIST" 2>/dev/null || true)"
    if [[ "$last_line" =~ ^#[[:space:]]*(jessie|stretch|buster|bullseye|bookworm|finalize)([[:space:]]+keep-packages)?$ ]]; then
        tmp_file="$(mktemp)"
        head -n -1 "$UCK_SOURCES_LIST" > "$tmp_file"
        echo "$marker" >> "$tmp_file"
        cat "$tmp_file" > "$UCK_SOURCES_LIST"
        rm -f "$tmp_file"
    else
        # Fallback if no trailing state marker exists.
        echo "$marker" >> "$UCK_SOURCES_LIST"
    fi
}

clear_state_marker() {
    local last_line=""
    while true; do
        last_line="$(tail -1 "$UCK_SOURCES_LIST" 2>/dev/null || true)"
        if [[ ! "$last_line" =~ ^#[[:space:]]*(jessie|stretch|buster|bullseye|bookworm|finalize)([[:space:]]+keep-packages)?$ ]]; then
            break
        fi
        if [[ "$DRY_RUN" == true ]]; then
            log "[DRY-RUN] Would remove state marker from $UCK_SOURCES_LIST: $last_line"
            break
        fi
        sed -i '$d' "$UCK_SOURCES_LIST"
    done
}

get_current_state() {
    local last_line=""
    last_line="$(tail -1 "$UCK_SOURCES_LIST" 2>/dev/null || true)"

    if [[ "$last_line" =~ ^#[[:space:]]*(jessie|stretch|buster|bullseye|bookworm|finalize)([[:space:]]+keep-packages)?$ ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
    return 0
}

load_state_options() {
    local last_line=""
    last_line="$(tail -1 "$UCK_SOURCES_LIST" 2>/dev/null || true)"

    if [[ "$last_line" =~ ^#[[:space:]]*(jessie|stretch|buster|bullseye|bookworm|finalize)([[:space:]]+keep-packages)?$ ]] && [[ -n "${BASH_REMATCH[2]}" ]]; then
        KEEP_PACKAGES=true
        log "Detected persisted keep-packages mode from state marker."
    fi
}

# --- Safety checks ---

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (try: sudo bash $0)"
        exit 1
    fi
}

# Require at least one Debian mirror to be reachable.
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
