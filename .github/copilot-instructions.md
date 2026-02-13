# Copilot Instructions

## Project Overview

Headless Debian upgrade tool for Ubiquiti UniFi Cloud Key Gen1. Upgrades through Debian releases (Jessie → Stretch → Buster → Bullseye → Bookworm), rebooting between each step.

## Architecture

- **Entrypoint**: `bin/uck-upgrade` — parses CLI flags, sources libraries, dispatches to the correct release function
- **Shared library**: `lib/common.sh` — logging, apt helpers (`apt_upgrade`, `apt_cleanup`), state management (`get_current_state`, `set_next_state`, `write_sources_list`), safety checks
- **Release modules**: `lib/releases/<release>.sh` — each file defines one function (e.g., `jessie()`, `stretch()`) containing release-specific upgrade logic
- **Backward-compat wrapper**: `update.sh` — thin wrapper that `exec`s `bin/uck-upgrade` so old rc.local entries still work
- **State machine**: Progress is tracked via a comment on the last line of `/etc/apt/sources.list` (e.g., `# stretch`). When no marker is found, the upgrade is complete.

## Conventions

- All destructive commands go through the `run` wrapper in `common.sh` so `--dry-run` works globally
- All output goes through `log()` which writes to both stdout and `/var/log/uck-upgrade.log`
- `jessie.sh` is unique: it removes UniFi packages and disables Ubiquiti services before upgrading
- Each release function follows the pattern: `write_sources_list` → `set_next_state(current)` → `apt_upgrade` → optional `apt_cleanup` → `transition_state(next)` → `safe_reboot`
- `bookworm.sh` schedules a separate `finalize` state; `finalize.sh` runs final slim cleanup and clears the state marker
- Final stage runs slim-mode purge by default; use `--keep-packages` to opt out (persisted via state marker across reboots)

## Validation

- All `.sh` files and `bin/uck-upgrade` must pass `shellcheck --severity=warning`
- CI runs shellcheck via `.github/workflows/lint.yml`
- Use `--dry-run` to verify changes without executing destructive commands
