# Copilot Instructions

## Project Overview

Headless Debian upgrade tool for Ubiquiti UniFi Cloud Key Gen1. Upgrades through Debian releases (Jessie → Stretch → Buster → Bullseye → Bookworm), rebooting between each step.

## Architecture

- **Entrypoint**: `bin/uck-upgrade` — parses CLI flags, sources libraries, dispatches to the correct release function
- **Shared library**: `lib/common.sh` — logging, apt helpers (`apt_upgrade`, `apt_cleanup`), state management (`get_current_state`, `set_next_state`, `write_sources_list`), safety checks, self-healing hooks
- **Release modules**: `lib/releases/<release>.sh` — each file defines one function (e.g., `jessie()`, `stretch()`) containing release-specific upgrade logic
- **Backward-compat wrapper**: `update.sh` — thin wrapper that `exec`s `bin/uck-upgrade` so old rc.local entries still work
- **State machine**: Progress is tracked via a comment on the last line of `/etc/apt/sources.list` (e.g., `# stretch`). When no marker is found, the upgrade is complete.
- **Tests**: `tests/dry-run-smoke.sh` — CI smoke test that runs `--dry-run` with mocked system commands and validates all stages execute

## Conventions

- All destructive commands go through the `run` wrapper in `common.sh` so `--dry-run` works globally
- Non-critical commands use `run_optional` which allows failures without aborting
- All output goes through `log()` which writes to both stdout and `/var/log/uck-upgrade.log`
- All awk patterns must use `[ \t]` (not `[[:space:]]`) for mawk compatibility on Jessie
- All grep patterns use `[[:blank:]]` for POSIX portability
- `jessie.sh` is unique: it purges UniFi/Ubiquiti/freeradius packages (dependants first) and disables services before upgrading
- Each release function follows the pattern: `write_sources_list` → `set_next_state(current)` → `apt_upgrade` → optional `apt_cleanup` → `transition_state(next)` → `safe_reboot`
- `bookworm.sh` schedules a separate `finalize` state; `finalize.sh` runs final slim cleanup and clears the state marker
- Final stage runs slim-mode purge by default; use `--keep-packages` to opt out (persisted via state marker across reboots)

## Safety & Self-Healing

- **rc.local continuation**: `ensure_rc_local_continuation()` validates and repairs the rc.local boot hook on every run and before each reboot. Uses awk-based before-exit-0 validation with atomic write (mktemp + mv on same filesystem) and trap cleanup.
- **SSH continuity**: `ensure_ssh_continuity()` verifies openssh-server is installed and SSH service is active before every reboot. Refuses to reboot if SSH is down.
- **Network retry**: `check_network()` retries up to 12 times with 10s delays (2 min total) since rc.local runs before networking is fully up.
- **Ubiquiti hook disabling**: `disable_ubnt_hooks()` renames `/etc/apt/apt.conf.d/*ubnt*` and `/etc/dpkg/dpkg.cfg.d/*ubnt*` to `.disabled` before each `apt_upgrade` to prevent cross-release breakage.
- **Broken dependency repair**: `apt_upgrade()` runs `dpkg --configure -a` and `apt-get --fix-broken install` before every upgrade/dist-upgrade.
- **Bookworm-specific**: Unmounts `/lib/modules` before upgrade (AUFS usrmerge fix) and forces `PermitRootLogin yes` after upgrade (headless root access).
- **Buster EOL**: Uses `archive.debian.org` mirrors since Buster is end-of-life.

## Dry-Run Mode

- `--dry-run` simulates all upgrade stages sequentially (jessie → finalize) without rebooting, showing every command that would execute.
- All `run`, `run_optional`, `write_sources_list`, `set_next_state`, `transition_state`, and `safe_reboot` respect the `DRY_RUN` flag.

## Testing

- **Smoke test**: `tests/dry-run-smoke.sh` mocks system commands (ping, systemctl, dpkg-query, etc.) and overrides `UCK_SOURCES_LIST`, `UCK_RC_LOCAL`, `UCK_LOG_FILE` via environment variables, then validates dry-run output contains all expected stages and operations.
- Path constants in `lib/common.sh` accept environment overrides via `${VAR:-default}` pattern to support test isolation.
- CI runs the smoke test as a separate job (`dry-run-smoke`) alongside shellcheck.

## Validation

- All `.sh` files and `bin/uck-upgrade` must pass `shellcheck --severity=warning`
- CI runs shellcheck and dry-run smoke test via `.github/workflows/lint.yml`
- Use `--dry-run` to verify changes without executing destructive commands
- Never push directly to main — always use feature branches and PRs
