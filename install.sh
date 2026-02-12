#!/bin/bash
# Installer for UCK Gen1 Debian Upgrade
#
# Automates the setup described in README.md:
# - Copies scripts to ~/UCK/
# - Configures /etc/rc.local to run on boot

set -euo pipefail

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_HOME="${TARGET_HOME:-$HOME}"
INSTALL_DIR="${TARGET_HOME}/UCK"
RC_LOCAL="/etc/rc.local"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RC_LOCAL_MARKER="# UCK-GEN1-UPGRADE"
RC_LOCAL_CMD="sudo bash ${INSTALL_DIR}/bin/uck-upgrade"

echo "=== UCK Gen1 Upgrade Installer ==="
echo ""

# Check root
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Run this script with sudo: sudo bash install.sh" >&2
    exit 1
fi

# Copy project files
echo "Installing to $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"
cp -r "$SCRIPT_DIR/bin" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/lib" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/update.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/uninstall.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/bin/uck-upgrade"
chmod +x "$INSTALL_DIR/update.sh"
chmod +x "$INSTALL_DIR/uninstall.sh"

# Set up rc.local
if [[ -f "$RC_LOCAL" ]] && grep -q "$RC_LOCAL_MARKER" "$RC_LOCAL"; then
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
        # Insert before 'exit 0' if it exists, otherwise append
        if grep -q "^exit 0" "$RC_LOCAL"; then
            sed -i \
                -e "/^exit 0/i\\$RC_LOCAL_MARKER" \
                -e "/^exit 0/i\\$RC_LOCAL_CMD" \
                "$RC_LOCAL"
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
