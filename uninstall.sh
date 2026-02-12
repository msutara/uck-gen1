#!/bin/bash
# Uninstaller for UCK Gen1 Debian Upgrade
#
# Removes the rc.local entry and optionally the install directory.

set -euo pipefail

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_HOME="${TARGET_HOME:-$HOME}"
INSTALL_DIR="${TARGET_HOME}/UCK"
RC_LOCAL="/etc/rc.local"
RC_LOCAL_MARKER="# UCK-GEN1-UPGRADE"

echo "=== UCK Gen1 Upgrade Uninstaller ==="
echo ""

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Run this script with sudo: sudo bash uninstall.sh" >&2
    exit 1
fi

# Remove rc.local entry
if [[ -f "$RC_LOCAL" ]] && grep -q "$RC_LOCAL_MARKER" "$RC_LOCAL"; then
    echo "Removing upgrade entry from $RC_LOCAL ..."
    sed -i "/$RC_LOCAL_MARKER/d" "$RC_LOCAL"
    sed -i '/UCK\/bin\/uck-upgrade/d' "$RC_LOCAL"
    # Also remove legacy entry if present
    sed -i '/UCK\/update.sh/d' "$RC_LOCAL"
    echo "Done."
else
    echo "No upgrade entry found in $RC_LOCAL — skipping."
fi

# Remove install directory
if [[ -d "$INSTALL_DIR" ]]; then
    read -rp "Remove $INSTALL_DIR? [y/N] " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -rf "$INSTALL_DIR"
        echo "Removed $INSTALL_DIR"
    else
        echo "Kept $INSTALL_DIR"
    fi
else
    echo "Install directory $INSTALL_DIR not found — skipping."
fi

echo ""
echo "Uninstall complete."
