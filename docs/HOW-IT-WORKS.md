# How It Works

## Upgrade Path

The script upgrades through Debian releases sequentially:

```txt
Jessie (8) → Stretch (9) → Buster (10) → Bullseye (11) → Finalize
```

Bullseye is the final target — Bookworm (Debian 12) is incompatible with UCK Gen1 hardware.
See [BOOKWORM-FINDINGS.md](BOOKWORM-FINDINGS.md) for details.

Each step requires a reboot. The script is designed to resume automatically after each reboot via `/etc/rc.local`.

## State Machine

The upgrade progress is tracked using a comment on the last line of `/etc/apt/sources.list`. The flow works like this:

1. **On boot**, the script reads the last line of `sources.list`
2. If the last line is a comment like `# stretch`, it extracts `stretch` as the current state
3. It calls the function matching that state name (e.g., `stretch()`)
4. The function:
   - Overwrites `sources.list` with the correct mirrors for that release
   - Calls `set_next_state("<current>")` so an unexpected reboot resumes the same release step
   - Runs `apt-get update`, `upgrade`, and `dist-upgrade`
   - On success, calls `transition_state("<next>")` so the marker becomes the next release (e.g., `# buster`)
   - Reboots
5. On next boot, the script picks up the updated marker and continues
6. When no state marker is found, the upgrade is complete

### State Transitions

```txt
sources.list ends with "# jessie"   → jessie()   → set_next_state("jessie")   → apt upgrade → transition_state("stretch")  → reboot
sources.list ends with "# stretch"  → stretch()  → set_next_state("stretch")  → apt upgrade → transition_state("buster")   → reboot
sources.list ends with "# buster"   → buster()   → set_next_state("buster")   → apt upgrade → transition_state("bullseye") → reboot
sources.list ends with "# bullseye" → bullseye() → set_next_state("bullseye") → apt upgrade → transition_state("finalize") → reboot
sources.list ends with "# finalize" → finalize() → final slim + cleanup      → clear marker                → done
```

## Initial Jessie Detection

The first run has special logic: if the system is on Jessie and no state marker exists yet, the script appends `# jessie` to bootstrap the state machine.

## Jessie Stage — Special Handling

The Jessie stage is unique because it must:

- Remove the UniFi controller package (`dpkg -P unifi`)
- Disable Ubiquiti-specific services (cloudkey-webui, ubnt-systemhub, etc.)
- Import Debian archive signing keys
- Clear `/etc/apt/sources.list.d/`

These steps are only needed once, before the first upgrade.

## Safety Mechanisms

- **Ctrl+C trap**: Interrupting the script triggers `ubnt-systool reset2defaults` (factory reset) as a recovery safeguard
- **Non-interactive apt**: All apt operations use `DEBIAN_FRONTEND=noninteractive` with `--force-confnew` to avoid hanging on prompts
- **Root check**: The script verifies it is running as root before starting
- **Mirror check behavior**: The script requires at least one of the Debian mirrors (`deb.debian.org` or `archive.debian.org`) to be reachable before proceeding
- **Network check**: Verifies connectivity to Debian mirrors before attempting apt operations

## File Structure

```txt
bin/uck-upgrade          Main entrypoint — argument parsing, state dispatch
lib/common.sh            Shared functions (logging, apt helpers, state management)
lib/releases/jessie.sh   Jessie-specific upgrade logic
lib/releases/stretch.sh  Stretch upgrade logic
lib/releases/buster.sh   Buster upgrade logic
lib/releases/bullseye.sh Bullseye upgrade logic
lib/releases/finalize.sh Final cleanup (slim + apt cleanup)
```
