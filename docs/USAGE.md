# Usage Guide

## Quick Start

SSH into your Cloud Key (default credentials: `ubnt`/`ubnt`) and run:

```bash
wget https://github.com/msutara/uck-gen1/archive/refs/heads/main.tar.gz -O /tmp/uck-gen1.tar.gz
tar -xzf /tmp/uck-gen1.tar.gz -C /tmp
sudo bash /tmp/uck-gen1-main/install.sh
sudo reboot
```

The upgrade will proceed automatically through each reboot.

## Command-Line Options

```txt
Usage: uck-upgrade [OPTIONS]

Options:
  --dry-run     Show what would happen without making changes
  --keep-packages
                Keep optional packages and skip final slimming purge
  --status      Show current upgrade state and recent log entries
  --version     Show version
  -h, --help    Show this help message
```

### Dry Run

Preview the entire upgrade process without making any changes:

```bash
sudo bash ~/UCK/bin/uck-upgrade --dry-run
```

This will log every command that *would* be executed, including:

- Which sources.list would be written
- Which apt commands would run
- When a reboot would occur

### Check Status

See where you are in the upgrade process:

```bash
sudo bash ~/UCK/bin/uck-upgrade --status
```

This shows the current OS version, next upgrade stage, and recent log entries.

## Logs

All upgrade activity is logged to `/var/log/uck-upgrade.log` with timestamps. This file persists across reboots, so you can review the full history after the upgrade completes:

```bash
cat /var/log/uck-upgrade.log
```

## Slim Mode

By default, a dedicated final cleanup stage (after Bookworm) purges optional packages to keep the OS slim (for example: UniFi app stack, Java runtime, nginx/php-fpm, and setup helpers when present).

If you want to keep those optional packages, run with:

```bash
sudo bash ~/UCK/bin/uck-upgrade --keep-packages
```

When this flag is used, the keep-packages preference is persisted in the stage marker and survives reboots until the final cleanup stage completes.

## Manual Installation

If you prefer not to use the installer script:

1. Download the repository to `~/UCK/`
2. Add this line to `/etc/rc.local` (before `exit 0`):

   ```bash
   bash ~/UCK/bin/uck-upgrade
   ```

3. Make rc.local executable: `chmod +x /etc/rc.local`
4. Reboot

## Uninstalling

To remove the upgrade automation:

```bash
sudo bash ~/UCK/uninstall.sh
```

This removes the rc.local entry and optionally deletes the `~/UCK/` directory.
