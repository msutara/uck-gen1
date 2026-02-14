#!/bin/bash
# Common functions for UCK Gen1 Debian upgrade
# Sourced by bin/uck-upgrade and lib/releases/*.sh

readonly UCK_LOG_FILE="/var/log/uck-upgrade.log"
readonly UCK_SOURCES_LIST="/etc/apt/sources.list"
readonly UCK_RC_LOCAL="/etc/rc.local"
readonly UCK_RC_LOCAL_MARKER="# UCK-GEN1-UPGRADE"
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

# Disable any Ubiquiti dpkg/apt hooks that break across major releases.
disable_ubnt_hooks() {
    local f
    for f in /etc/apt/apt.conf.d/*ubnt* /etc/dpkg/dpkg.cfg.d/*ubnt*; do
        if [[ -f "$f" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                log "[DRY-RUN] Would disable hook: $f"
            elif mv "$f" "${f}.disabled"; then
                log "Disabled hook: $f"
            else
                log_error "Failed to disable hook: $f — apt may fail"
            fi
        fi
    done
}

apt_upgrade() {
    disable_ubnt_hooks
    run apt-get -qy update
    run_optional dpkg --configure -a
    run_optional apt-get -qy -o "Dpkg::Options::=--force-confnew" --fix-broken install
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

ensure_ssh_continuity() {
    local ssh_service=""

    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY-RUN] Would ensure openssh-server is installed and SSH service is enabled"
        return 0
    fi

    if ! dpkg-query -W -f='${Status}' openssh-server 2>/dev/null | grep -q "install ok installed"; then
        log "Installing openssh-server to preserve remote access..."
        run apt-get -qy install openssh-server
    fi

    if [[ -f /lib/systemd/system/ssh.service || -f /etc/systemd/system/ssh.service ]]; then
        ssh_service="ssh"
    elif [[ -f /lib/systemd/system/sshd.service || -f /etc/systemd/system/sshd.service ]]; then
        ssh_service="sshd"
    fi

    if [[ -z "$ssh_service" ]]; then
        log_error "Could not find SSH service unit (ssh.service or sshd.service). Refusing to reboot."
        exit 1
    fi

    run systemctl enable "$ssh_service"
    run systemctl start "$ssh_service"

    if ! systemctl is-active --quiet "$ssh_service"; then
        log_error "SSH service '$ssh_service' is not active. Refusing to reboot."
        exit 1
    fi
}

# Ensure rc.local always contains the continuation command while upgrade is in progress.
ensure_rc_local_continuation() {
    local continuation_cmd="$1"
    local tmp_rc=""

    if [[ -z "$continuation_cmd" ]]; then
        return 0
    fi

    if [[ -f "$UCK_RC_LOCAL" ]] &&
       awk -v marker="$UCK_RC_LOCAL_MARKER" -v cmd="$continuation_cmd" '
           /^[ \t]*exit[ \t]+0[ \t]*$/ {
               saw_exit = 1
           }
           !saw_exit && index($0, marker) {
               marker_ok = 1
           }
           !saw_exit && index($0, cmd) {
               cmd_ok = 1
           }
           END {
               exit !(marker_ok && cmd_ok)
           }
       ' "$UCK_RC_LOCAL"; then
        if [[ -x "$UCK_RC_LOCAL" ]]; then
            return 0
        fi

        log "Fixing execute permissions on $UCK_RC_LOCAL"
        if [[ "$DRY_RUN" == true ]]; then
            log "[DRY-RUN] Would run: chmod +x $UCK_RC_LOCAL"
        else
            chmod +x "$UCK_RC_LOCAL"
        fi
        return 0
    fi

    log "Ensuring reboot continuation hook in $UCK_RC_LOCAL"

    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY-RUN] Would ensure marker '$UCK_RC_LOCAL_MARKER' and command '$continuation_cmd' in $UCK_RC_LOCAL"
        return 0
    fi

    if [[ ! -f "$UCK_RC_LOCAL" ]]; then
        cat <<EOF > "$UCK_RC_LOCAL"
#!/bin/sh -e
# rc.local — executed at the end of each multiuser runlevel.

$UCK_RC_LOCAL_MARKER
$continuation_cmd

exit 0
EOF
        chmod +x "$UCK_RC_LOCAL"
        return 0
    fi

    sed -i "\|$UCK_RC_LOCAL_MARKER|d" "$UCK_RC_LOCAL"
    sed -i '/UCK\/bin\/uck-upgrade/d' "$UCK_RC_LOCAL"
    sed -i '/UCK\/update\.sh/d' "$UCK_RC_LOCAL"

    if grep -Eq '^[[:blank:]]*exit[[:blank:]]+0[[:blank:]]*$' "$UCK_RC_LOCAL"; then
        tmp_rc="$(mktemp /etc/rc.local.XXXXXX)"
        # shellcheck disable=SC2064
        trap "rm -f '$tmp_rc'" EXIT
        awk -v marker="$UCK_RC_LOCAL_MARKER" -v cmd="$continuation_cmd" '
            /^[ \t]*exit[ \t]+0[ \t]*$/ && !inserted {
                print marker
                print cmd
                inserted = 1
            }
            { print }
        ' "$UCK_RC_LOCAL" > "$tmp_rc"
        if mv "$tmp_rc" "$UCK_RC_LOCAL"; then
            trap - EXIT
        else
            rm -f "$tmp_rc"
            trap - EXIT
            log_error "Failed to update $UCK_RC_LOCAL"
            return 1
        fi
    else
        echo "" >> "$UCK_RC_LOCAL"
        echo "$UCK_RC_LOCAL_MARKER" >> "$UCK_RC_LOCAL"
        echo "$continuation_cmd" >> "$UCK_RC_LOCAL"
    fi

    chmod +x "$UCK_RC_LOCAL"
}

# --- Safety checks ---

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (try: sudo bash $0)"
        exit 1
    fi
}

# Require at least one Debian mirror to be reachable.
# Retries with backoff since rc.local may run before networking is fully up.
check_network() {
    local attempt max_attempts=12 wait_secs=10

    for (( attempt=1; attempt<=max_attempts; attempt++ )); do
        if ping -c 1 -W 5 deb.debian.org &>/dev/null ||
           ping -c 1 -W 5 archive.debian.org &>/dev/null; then
            return 0
        fi
        if (( attempt < max_attempts )); then
            log "Network not ready, retrying in ${wait_secs}s (attempt $attempt/$max_attempts)..."
            sleep "$wait_secs"
        fi
    done

    log_error "Cannot reach Debian mirrors after $max_attempts attempts — check network connectivity"
    exit 1
}

# --- Reboot ---

safe_reboot() {
    ensure_ssh_continuity

    if [[ -n "${UCK_CONTINUATION_CMD:-}" ]]; then
        ensure_rc_local_continuation "$UCK_CONTINUATION_CMD"
    fi
    log "Stage complete. Rebooting to continue upgrade..."
    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY-RUN] Would reboot now"
    else
        # Non-returning in normal operation: replace current process with reboot command.
        exec reboot
    fi
}
