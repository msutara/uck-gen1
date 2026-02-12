# uck-gen1

Headless Debian upgrade for Ubiquiti UniFi Cloud Key Gen1.

Automatically upgrades through Debian releases across reboots:

```txt
Jessie (8) → Stretch (9) → Buster (10) → Bullseye (11) → Bookworm (12)
```

## Quick Start

1. Boot your Cloud Key into recovery mode, factory reset, then reboot
2. SSH in (default credentials: `ubnt`/`ubnt`)
3. Run:

```bash
wget https://github.com/msutara/uck-gen1/archive/refs/heads/main.tar.gz -O /tmp/uck-gen1.tar.gz
tar -xzf /tmp/uck-gen1.tar.gz -C /tmp
sudo bash /tmp/uck-gen1-main/install.sh
sudo reboot
```

The upgrade runs automatically after each reboot. Monitor progress via:

```bash
sudo bash ~/UCK/bin/uck-upgrade --status
```

## Features

- **Fully automated** — runs unattended across multiple reboots
- **Dry-run mode** — preview changes with `--dry-run` before committing
- **Persistent logging** — full history in `/var/log/uck-upgrade.log`
- **Safe interruption** — Ctrl+C triggers factory reset as a recovery safeguard

## Documentation

- [Usage Guide](docs/USAGE.md) — installation, CLI options, and uninstalling
- [How It Works](docs/HOW-IT-WORKS.md) — architecture and state machine design
- [Troubleshooting](docs/TROUBLESHOOTING.md) — common issues and recovery steps

## ⚠️ Warning

This script makes destructive changes to system packages and configuration. It is designed **only** for the UniFi Cloud Key Gen1. Do not run on other hardware.

## License

See [LICENSE](LICENSE) for details.
