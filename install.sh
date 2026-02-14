#!/bin/bash
# Installer for UCK Gen1 Debian Upgrade
#
# Automates the setup described in README.md:
# - Copies scripts to ~/UCK/
# - Configures /etc/rc.local to run on boot

set -euo pipefail

TARGET_USER="${SUDO_USER:-${USER:-root}}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6 || true)"
TARGET_HOME="${TARGET_HOME:-${HOME:-/root}}"
INSTALL_DIR="${TARGET_HOME}/UCK"
RC_LOCAL="/etc/rc.local"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RC_LOCAL_MARKER="# UCK-GEN1-UPGRADE"
RC_LOCAL_CMD="bash ${INSTALL_DIR}/bin/uck-upgrade"

echo "=== UCK Gen1 Upgrade Installer ==="
echo ""

# Check root
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Run this script with sudo: sudo bash install.sh" >&2
    exit 1
fi

# Validate required project files before installation.
required_paths=(
    "bin/uck-upgrade"
    "lib/common.sh"
    "lib/releases/jessie.sh"
    "lib/releases/stretch.sh"
    "lib/releases/buster.sh"
    "lib/releases/bullseye.sh"
    "lib/releases/bookworm.sh"
    "lib/releases/finalize.sh"
    "update.sh"
    "uninstall.sh"
    "docs/USAGE.md"
    "docs/HOW-IT-WORKS.md"
    "docs/TROUBLESHOOTING.md"
)

for rel_path in "${required_paths[@]}"; do
    if [[ ! -e "$SCRIPT_DIR/$rel_path" ]]; then
        echo "ERROR: Missing required file: $SCRIPT_DIR/$rel_path" >&2
        echo "Please re-download a complete repository snapshot." >&2
        exit 1
    fi
done

# Copy project files
echo "Installing to $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"
cp -r "$SCRIPT_DIR/bin" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/lib" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/docs" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/update.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/uninstall.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/bin/uck-upgrade"
chmod +x "$INSTALL_DIR/update.sh"
chmod +x "$INSTALL_DIR/uninstall.sh"

# Ensure installed files are owned by the target user, not root.
TARGET_GROUP="$(id -gn "$TARGET_USER" 2>/dev/null || true)"
if [[ -n "$TARGET_GROUP" ]]; then
    chown -R "${TARGET_USER}:${TARGET_GROUP}" "$INSTALL_DIR"
else
    chown -R "$TARGET_USER" "$INSTALL_DIR"
fi

# Set up rc.local
if [[ -f "$RC_LOCAL" ]] &&
   [[ -x "$RC_LOCAL" ]] &&
   awk -v marker="$RC_LOCAL_MARKER" -v cmd="$RC_LOCAL_CMD" '
       /^[ \t]*exit[ \t]+0[ \t]*$/ { exit }
       { if (index($0, marker)) m=1; if (index($0, cmd)) c=1 }
       END { exit !(m && c) }
   ' "$RC_LOCAL"; then
    echo "rc.local already configured — skipping."
else
    echo "Configuring $RC_LOCAL ..."
    if [[ ! -f "$RC_LOCAL" ]]; then
        cat <<EOF > "$RC_LOCAL"
#!/bin/sh -e
# rc.local — executed at the end of each multiuser runlevel.

$RC_LOCAL_MARKER
$RC_LOCAL_CMD

exit 0
EOF
    else
        sed -i "\|$RC_LOCAL_MARKER|d" "$RC_LOCAL"
        sed -i '/UCK\/bin\/uck-upgrade/d' "$RC_LOCAL"
        sed -i '/UCK\/update\.sh/d' "$RC_LOCAL"

        # Insert before 'exit 0' if it exists, otherwise append
        if grep -Eq '^[[:blank:]]*exit[[:blank:]]+0[[:blank:]]*$' "$RC_LOCAL"; then
            tmp_rc="$(mktemp)"
            awk -v marker="$RC_LOCAL_MARKER" -v cmd="$RC_LOCAL_CMD" '
                /^[ \t]*exit[ \t]+0[ \t]*$/ && !inserted {
                    print marker
                    print cmd
                    inserted = 1
                }
                { print }
            ' "$RC_LOCAL" > "$tmp_rc"
            cat "$tmp_rc" > "$RC_LOCAL"
            rm -f "$tmp_rc"
        else
            echo "" >> "$RC_LOCAL"
            echo "$RC_LOCAL_MARKER" >> "$RC_LOCAL"
            echo "$RC_LOCAL_CMD" >> "$RC_LOCAL"
        fi
    fi
    chmod +x "$RC_LOCAL"
fi

echo ""
echo "Installation complete."
echo "Reboot to start the upgrade process, or run manually:"
echo "  sudo bash $INSTALL_DIR/bin/uck-upgrade --dry-run"
echo ""
