# uck-gen1

Headless Debian upgrade for Ubiquiti UniFi Cloud Key Gen1.

Automatically upgrades through Debian releases across reboots:

```txt
Jessie (8) → Stretch (9) → Buster (10) → Bullseye (11)
```

> **Bullseye (Debian 11) is the final target** — Bookworm (Debian 12) is
> [incompatible with UCK Gen1 hardware](docs/BOOKWORM-FINDINGS.md).
> After the final release upgrade, the script runs a cleanup stage that slims
> the installation by purging optional packages.

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
- **Safe target** — upgrades to Bullseye, the last release compatible with UCK Gen1
- **Dry-run mode** — preview changes with `--dry-run` before committing
- **Default slim mode** — purges optional packages on final stage (`--keep-packages` to skip)
- **Persistent logging** — full history in `/var/log/uck-upgrade.log`
- **Safe interruption** — Ctrl+C triggers factory reset as a recovery safeguard

## Documentation

- [Usage Guide](docs/USAGE.md) — installation, CLI options, and uninstalling
- [How It Works](docs/HOW-IT-WORKS.md) — architecture and state machine design
- [Troubleshooting](docs/TROUBLESHOOTING.md) — common issues and recovery steps
- [Bookworm Findings](docs/BOOKWORM-FINDINGS.md) — why Bookworm is not supported
- [Contributing](CONTRIBUTING.md) — development guidelines and PR process
- [Security Policy](SECURITY.md) — vulnerability reporting

## ⚠️ Warning

This script makes destructive changes to system packages and configuration. It is designed **only** for the UniFi Cloud Key Gen1. Do not run on other hardware.

## License

See [LICENSE](LICENSE) for details.
