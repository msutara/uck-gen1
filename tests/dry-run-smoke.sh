#!/bin/bash
# Dry-run smoke test — validates uck-upgrade --dry-run produces expected output.
# Runs on ubuntu-latest in CI with mocked system commands.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Setup mock environment ---

MOCK_DIR="$(mktemp -d)"
FAKE_SOURCES="$(mktemp)"
FAKE_RC_LOCAL="$(mktemp)"
FAKE_LOG="$(mktemp)"
trap 'rm -rf "$MOCK_DIR" "$FAKE_SOURCES" "$FAKE_RC_LOCAL" "$FAKE_LOG"' EXIT

# Create mock commands that succeed silently
for cmd in ping systemctl debconf-set-selections lsb_release ubnt-systool apt-key; do
    cat > "$MOCK_DIR/$cmd" <<'MOCK'
#!/bin/bash
exit 0
MOCK
    chmod +x "$MOCK_DIR/$cmd"
done

# Mock dpkg-query to return empty (no packages installed)
cat > "$MOCK_DIR/dpkg-query" <<'MOCK'
#!/bin/bash
exit 1
MOCK
chmod +x "$MOCK_DIR/dpkg-query"

# Prepend mocks to PATH
export PATH="$MOCK_DIR:$PATH"

# Create a fake sources.list with jessie content
cat > "$FAKE_SOURCES" <<EOF
deb https://archive.debian.org/debian/ jessie main contrib non-free
deb https://archive.debian.org/debian-security/ jessie/updates main contrib non-free
EOF

# Create a fake rc.local
cat > "$FAKE_RC_LOCAL" <<'EOF'
#!/bin/sh -e
exit 0
EOF
chmod +x "$FAKE_RC_LOCAL"

# Override paths so the script uses our fakes
export UCK_SOURCES_LIST="$FAKE_SOURCES"
export UCK_RC_LOCAL="$FAKE_RC_LOCAL"
export UCK_LOG_FILE="$FAKE_LOG"

# --- Run dry-run ---

echo "=== Running dry-run smoke test ==="

output="$(bash "$REPO_DIR/bin/uck-upgrade" --dry-run 2>&1)" || {
    echo "FAIL: uck-upgrade --dry-run exited with non-zero status"
    echo "$output"
    exit 1
}

echo "$output"
echo ""

# --- Validate output ---

PASS=0
FAIL=0

assert_contains() {
    local label="$1"
    local pattern="$2"
    if printf '%s\n' "$output" | grep -qE "$pattern"; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label (expected pattern: $pattern)"
        FAIL=$((FAIL + 1))
    fi
}

assert_literal() {
    local label="$1"
    local text="$2"
    if printf '%s\n' "$output" | grep -qF -- "$text"; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label (expected literal: $text)"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Validating output ==="

# All stages must appear
assert_contains "Jessie stage runs"       "Starting upgrade stage: jessie"
assert_contains "Stretch stage runs"      "Starting upgrade stage: stretch"
assert_contains "Buster stage runs"       "Starting upgrade stage: buster"
assert_contains "Bullseye stage runs"     "Starting upgrade stage: bullseye"
assert_contains "Bookworm stage runs"     "Starting upgrade stage: bookworm"
assert_contains "Finalize stage runs"     "Starting upgrade stage: finalize"

# Key operations must be logged
assert_contains "Sources.list writes"     "DRY-RUN.*Would write to"
assert_contains "State transitions"       "DRY-RUN.*Would replace trailing state marker"
assert_contains "Reboot simulation"       "DRY-RUN.*Would reboot now"
assert_contains "apt-get upgrade"         "DRY-RUN.*Would run.*apt-get.*[^-]upgrade"
assert_contains "apt-get dist-upgrade"    "DRY-RUN.*Would run.*dist-upgrade"
assert_contains "Jessie bootstrap"        "DRY-RUN.*Bootstrapping initial state.*jessie"
assert_contains "rc.local hook"           "DRY-RUN.*Would ensure marker"

# Bookworm-specific
assert_contains "Bookworm usrmerge fix"   "DRY-RUN.*Would run.*umount.*/lib/modules"
assert_contains "Bookworm SSH fix"        "DRY-RUN.*Would run.*PermitRootLogin"

# Verify overridden paths are used (not system defaults)
assert_literal "Uses fake sources.list"  "Would write to $FAKE_SOURCES"
assert_literal "Uses fake rc.local"      "in $FAKE_RC_LOCAL"

# Finalize
assert_contains "Upgrade complete"        "Upgrade complete"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
