#!/bin/bash
# Backward-compatible wrapper for uck-upgrade
# Kept so existing rc.local entries referencing update.sh continue to work.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -x "$SCRIPT_DIR/bin/uck-upgrade" ]]; then
    exec bash "$SCRIPT_DIR/bin/uck-upgrade" "$@"
else
    echo "ERROR: bin/uck-upgrade not found. Re-download from:" >&2
    echo "  https://github.com/msutara/uck-gen1" >&2
    exit 1
fi
