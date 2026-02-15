# Bookworm (Debian 12) — Field Testing Results

## Summary

Upgrading the UniFi Cloud Key Gen1 from Bullseye (Debian 11) to Bookworm (Debian 12) is **not possible** with the current hardware configuration. The root cause is the AUFS overlay root filesystem, which is incompatible with Debian's mandatory `usrmerge` package in Bookworm.

## Root Cause: AUFS and usrmerge

The UCK Gen1 uses an AUFS overlay as its root filesystem (`aufs-root on / type aufs`). Starting with Bookworm, Debian requires merged `/usr` — meaning `/bin`, `/sbin`, and `/lib` must be symlinks to `/usr/bin`, `/usr/sbin`, and `/usr/lib` respectively.

The `usrmerge` package performs this conversion by renaming (`mv`) the top-level directories. However, AUFS returns `EBUSY` for all three directories because they are branch mount points in the overlay filesystem. This cannot be resolved by stopping services or unmounting — the directories are structurally part of the AUFS mount.

Without merged `/usr`, Bookworm's `systemd` package installs new binaries to `/usr/bin/` (expecting `/bin/` to be a symlink to it), but the old Bullseye binaries remain in `/bin/`. These old binaries link to `libsystemd-shared-247.so`, while the new library is `libsystemd-shared-252.so`. The result: systemd tools crash on every invocation, and the system becomes unbootable after reboot.

## What Was Tried

### Attempt 1: Stop udevd and unmount /lib/modules

**Rationale**: Initial error was specifically about `/lib/modules` being held open by `systemd-udevd`.

**Steps**:

```bash
systemctl stop systemd-udevd-kernel.socket systemd-udevd-control.socket
umount /lib/modules
apt-get -qy -o Dpkg::Options::=--force-confnew install usrmerge
```

**Result**: Failed. Even with udevd stopped and `/lib/modules` unmounted, `convert-usrmerge` still could not move `/lib/modules` — AUFS returned `EBUSY` regardless of process state.

### Attempt 2: Patch convert-usrmerge to skip /lib/modules

**Rationale**: If only `/lib/modules` was the problem, skip it.

**Steps**:

```bash
sed -i 's|/lib/modules|#SKIP_lib_modules|g' /usr/lib/usrmerge/convert-usrmerge
dpkg --configure usrmerge
```

**Result**: Failed. The sed pattern did not match because the script uses `/lib/modules/` (trailing slash). More importantly, when the script proceeded past `/lib/modules`, it also failed on `/bin/`, `/sbin/`, and `/lib/` — all returning `EBUSY`. The problem is not specific to `/lib/modules` but affects all top-level AUFS branch directories.

### Attempt 3: Manual copy + symlink for /lib/modules

**Rationale**: Bypass `mv` by copying contents and creating a symlink.

**Steps**:

```bash
cp -a /lib/modules /usr/lib/modules
rm -rf /lib/modules        # Failed: "Device or resource busy"
ln -s usr/lib/modules /lib/modules   # Created alongside the directory
/usr/lib/usrmerge/convert-usrmerge
```

**Result**: Partial. The `/lib/modules` symlink was created (coexisting with the directory), but `convert-usrmerge` then failed on `/bin/`, `/sbin/`, and `/lib/` with the same `EBUSY` error. This confirmed that the AUFS incompatibility affects all top-level directories, not just `/lib/modules`.

### Attempt 4: Purge usrmerge and proceed without merged /usr

**Rationale**: usrmerge is a policy package — maybe Bookworm works without it.

**Steps**:

```bash
dpkg --force-remove-reinstreq --purge usrmerge
apt-mark hold usrmerge usr-is-merged
apt-get -qy -o Dpkg::Options::=--force-confnew upgrade
apt-get -qy -o Dpkg::Options::=--force-confnew dist-upgrade
```

**Result**: The upgrade itself completed with errors. The `usr-is-merged` companion package also had to be held. The `systemd` package failed to configure because `systemd-machine-id-setup` (in `/bin/`) linked to `libsystemd-shared-247.so` which no longer existed.

### Attempt 5: Fix systemd library mismatch

**Rationale**: Create a compatibility symlink for the old library name.

**Steps tried**:

```bash
# Symlink in systemd lib directory
ln -sf /usr/lib/arm-linux-gnueabihf/systemd/libsystemd-shared-252.so \
       /usr/lib/arm-linux-gnueabihf/systemd/libsystemd-shared-247.so

# Symlink in standard lib path
ln -sf /usr/lib/arm-linux-gnueabihf/systemd/libsystemd-shared-252.so \
       /lib/arm-linux-gnueabihf/libsystemd-shared-247.so

# ldconfig configuration
echo "/usr/lib/arm-linux-gnueabihf/systemd" > /etc/ld.so.conf.d/systemd-shared.conf
ldconfig
```

**Result**: Failed. While ldconfig eventually found the symlink, the binary loaded it and crashed with `undefined symbol: log_assert_failed_unreachable_realm, version SD_SHARED`. The v247 and v252 libraries are ABI-incompatible — the old binaries cannot use the new library regardless of naming.

### Attempt 6: Remove systemd postinst scripts

**Rationale**: Skip the failing post-installation scripts to force configuration.

**Steps**:

```bash
rm -f /var/lib/dpkg/info/systemd.postinst
dpkg --configure systemd
rm -f /var/lib/dpkg/info/systemd-timesyncd.postinst
dpkg --configure systemd-timesyncd
dpkg --configure -a
apt-get -qy -o Dpkg::Options::=--force-confnew --fix-broken install
```

**Result**: Packages configured successfully. The system appeared functional — SSH was running, `PermitRootLogin yes` was set, password expiry was disabled, `lsb_release` showed Debian 12 (Bookworm). However, multiple systemd tools in `/bin/` remained broken (old v247 binaries).

### Attempt 7: Reboot

**Steps**:

```bash
reboot
```

**Result**: **System did not come back**. The device became unreachable via SSH and did not respond to ping. The broken systemd binaries in `/bin/` (which the init system relies on during boot) prevented the system from completing the boot sequence. Factory reset was required.

## Root Cause Analysis

The fundamental issue is a circular dependency on UCK Gen1:

1. Bookworm requires `usrmerge` (merged `/usr`)
2. `usrmerge` requires renaming `/bin`, `/sbin`, `/lib` to `/usr/bin`, `/usr/sbin`, `/usr/lib`
3. AUFS returns `EBUSY` for these renames because they are overlay branch directories
4. Without merged `/usr`, the Bookworm `systemd` package installs new binaries to `/usr/bin/` but old binaries persist in `/bin/`
5. Old binaries link to `libsystemd-shared-247.so`; new library is `libsystemd-shared-252.so` (ABI-incompatible)
6. systemd tools crash, system cannot boot

This is not a software bug — it is a fundamental incompatibility between the AUFS root filesystem used by UCK Gen1 and Debian's merged-/usr requirement starting with Bookworm.

## Automation That Was Built

Before field testing revealed the AUFS incompatibility, a complete automation
pipeline was developed for the Bookworm upgrade. This section documents what
was built, for reference if the AUFS limitation is ever resolved (e.g., by
Ubiquiti shipping a non-AUFS firmware, or by a future usrmerge that handles
overlay filesystems).

### The `--include-latest` Flag

A CLI flag was implemented to opt into the latest Debian release:

```bash
sudo bash ~/UCK/bin/uck-upgrade --include-latest
```

**Design:**

- Default behavior stopped at Bullseye (the last validated release)
- `--include-latest` opted into Bookworm as an additional stage
- The flag was persisted in the state marker (`# bullseye include-latest`) and
  survived reboots, so it only needed to be passed once
- The `INCLUDE_LATEST` variable controlled branching in `bullseye.sh`:
  - Without the flag: `transition_state "finalize"` → reboot → finalize
  - With the flag: `transition_state "bookworm"` → reboot → bookworm stage
- The dry-run loop dynamically included/excluded the bookworm stage based on
  the flag
- If the system was already at the `bookworm` state (from a prior run),
  `INCLUDE_LATEST` was forced to `true` since you can't un-upgrade

This flag was removed when Bookworm was confirmed incompatible.

### Smoke Test Changes for Bookworm

The dry-run smoke test (`tests/dry-run-smoke.sh`) required three additions when
Bookworm was an active stage. These were removed when Bookworm was dropped:

**1. Stage assertion** — add Bookworm to the "all stages must appear" block:

```bash
# All stages must appear
assert_contains "Jessie stage runs"       "Starting upgrade stage: jessie"
assert_contains "Stretch stage runs"      "Starting upgrade stage: stretch"
assert_contains "Buster stage runs"       "Starting upgrade stage: buster"
assert_contains "Bullseye stage runs"     "Starting upgrade stage: bullseye"
assert_contains "Bookworm stage runs"     "Starting upgrade stage: bookworm"
assert_contains "Finalize stage runs"     "Starting upgrade stage: finalize"
```

**2. Bookworm-specific assertions** — validate the usrmerge workaround and SSH
fix appear in dry-run output:

```bash
# Bookworm-specific
assert_contains "Bookworm usrmerge fix"   "DRY-RUN.*Would run.*umount.*/lib/modules"
assert_contains "Bookworm SSH fix"        "DRY-RUN.*Would run.*PermitRootLogin"
```

**3. STAGE_ORDER update** — the `STAGE_ORDER` array in `bin/uck-upgrade` must
include `bookworm` between `bullseye` and `finalize`:

```bash
declare -a STAGE_ORDER=(jessie stretch buster bullseye bookworm finalize)
```

Without this, the dry-run loop skips the Bookworm stage entirely and the stage
assertion fails. The `--include-latest` flag also required a second test run
to validate both default (Bullseye-only) and opt-in (Bookworm) modes.

### The bookworm.sh Stage Function

The following `bookworm()` function was developed and field-tested. It
addressed several Bookworm-specific issues but could not overcome the
fundamental AUFS/usrmerge incompatibility:

```bash
#!/bin/bash
# Bookworm — final upgrade stage (Debian 12)

bookworm() {
    log "=== Starting Bookworm upgrade stage ==="

    write_sources_list "deb https://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb https://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb https://deb.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware"

    set_next_state "bookworm"

    # Workaround: usrmerge cannot work on UCK Gen1's AUFS root filesystem.
    # Purge it and hold to prevent apt from reinstalling it during upgrade.
    log "Preventing usrmerge on AUFS root filesystem..."
    disable_ubnt_hooks
    run apt-get -qy update
    if dpkg-query -W -f='${Status}' usrmerge 2>/dev/null | grep -qE "installed|half"; then
        log "Removing incompatible usrmerge package..."
        run dpkg --force-remove-reinstreq --purge usrmerge
    fi
    run_optional apt-mark hold usrmerge usr-is-merged

    apt_upgrade

    # Bookworm defaults to PermitRootLogin prohibit-password; --force-confnew
    # overwrites sshd_config, locking out headless root-password access.
    log "Ensuring root SSH password login remains enabled..."
    run sed -i -E \
        's/^[[:blank:]]*#?[[:blank:]]*PermitRootLogin[[:blank:]].*/PermitRootLogin yes/' \
        /etc/ssh/sshd_config
    run sh -c "grep -Eq '^[[:blank:]]*PermitRootLogin[[:blank:]]+' /etc/ssh/sshd_config \
        || echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config"

    # Disable root password expiry to avoid forced password-change prompts.
    log "Disabling root password expiry..."
    run chage -M -1 root

    # Reload SSH with the correct service unit name.
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
```

**What this function handled:**

- **usrmerge purge + hold**: Removed and held `usrmerge` and `usr-is-merged` packages
- **Ubiquiti hook disabling**: Called `disable_ubnt_hooks` before apt operations
- **SSH root login**: Forced `PermitRootLogin yes` after `--force-confnew` overwrites sshd_config
- **Password expiry**: Disabled root password aging via `chage -M -1 root`
- **SSH service detection**: Used `detect_ssh_unit()` helper to handle both `ssh` and `sshd` unit names

**What it could NOT handle:**

- The systemd binary mismatch (`/bin/systemd-*` linking to old `libsystemd-shared-247.so`)
- The fundamental AUFS EBUSY on `/bin`, `/sbin`, `/lib` directory renames
- Any systemd tool invocation during package post-install scripts

### Manual Steps That Were Tested

The following manual procedure was validated on hardware (February 2026).
The upgrade appeared successful until reboot:

```bash
# 1. Write bookworm sources
cat > /etc/apt/sources.list << 'EOF'
deb https://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb https://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb https://deb.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware
EOF

# 2. Update and fix broken state
apt-get -qy update
dpkg --configure -a
apt-get -qy -o Dpkg::Options::=--force-confnew --fix-broken install

# 3. Purge and hold usrmerge (AUFS-incompatible)
dpkg --force-remove-reinstreq --purge usrmerge
apt-mark hold usrmerge usr-is-merged

# 4. Upgrade
apt-get -qy -o Dpkg::Options::=--force-confnew upgrade
apt-get -qy -o Dpkg::Options::=--force-confnew dist-upgrade

# 5. Fix systemd postinst failures (library mismatch)
rm -f /var/lib/dpkg/info/systemd.postinst
dpkg --configure systemd
rm -f /var/lib/dpkg/info/systemd-timesyncd.postinst
dpkg --configure systemd-timesyncd
dpkg --configure -a

# 6. Post-upgrade fixes
sed -i -E 's/^[[:blank:]]*#?[[:blank:]]*PermitRootLogin[[:blank:]].*/PermitRootLogin yes/' /etc/ssh/sshd_config
chage -M -1 root
systemctl reload-or-restart ssh

# 7. Cleanup
apt-get -qy --purge autoremove
apt-get -qy autoclean

# 8. Verify (all passed)
lsb_release -a          # Debian GNU/Linux 12 (bookworm) ✓
systemctl status ssh     # active (running) ✓
chage -l root            # Password expires: never ✓
dpkg --audit             # Only bt-proxy (harmless Ubiquiti artifact) ✓

# 9. Reboot
reboot                   # System did not come back ✗
```

## Conclusion

**Bullseye (Debian 11) is the highest supported Debian release for UCK Gen1.** Bullseye LTS is supported until August 2026. After that date, the device will not receive security updates from Debian.

Users who require Bookworm or later should consider migrating to different hardware.
