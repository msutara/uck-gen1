# Troubleshooting

## Checking Progress

View the current upgrade state and recent log output:

```bash
sudo bash ~/UCK/bin/uck-upgrade --status
```

Review the full log:

```bash
cat /var/log/uck-upgrade.log
```

## Common Issues

### Upgrade appears stuck (not progressing after reboot)

1. Check if the script is configured in rc.local:

   ```bash
   cat /etc/rc.local
   ```

   You should see a line containing `uck-upgrade` or `update.sh`.

2. Check the current state:

   ```bash
   tail -1 /etc/apt/sources.list
   ```

   This should show a comment like `# stretch`, `# buster`, etc.

3. Try running the script manually to see errors:

   ```bash
   sudo bash ~/UCK/bin/uck-upgrade
   ```

### APT errors during upgrade

If apt-get fails during an upgrade stage:

1. Check network connectivity:

   ```bash
   ping -c 3 deb.debian.org
   ping -c 3 archive.debian.org
   ```

2. Try running the failed stage manually:

   ```bash
   sudo apt-get update
   sudo apt-get -qy -o "Dpkg::Options::=--force-confnew" upgrade
   sudo apt-get -qy -o "Dpkg::Options::=--force-confnew" dist-upgrade
   ```

3. If packages are broken:

   ```bash
   sudo dpkg --configure -a
   sudo apt-get -f install
   ```

### Factory reset was triggered

If you pressed Ctrl+C during the upgrade, the safety trap triggers `ubnt-systool reset2defaults`. You'll need to start the process from the beginning:

1. Boot into recovery mode
2. Factory reset
3. Re-run the installer

### Script not found after reboot

The install directory might have been removed during the upgrade. Re-download:

```bash
wget https://github.com/msutara/uck-gen1/archive/refs/heads/main.tar.gz -O /tmp/uck-gen1.tar.gz
tar -xzf /tmp/uck-gen1.tar.gz -C /tmp
sudo bash /tmp/uck-gen1-main/install.sh
```

### SSH connection lost during upgrade

This is expected — the Cloud Key reboots between each stage. Wait 2–3 minutes and reconnect:

```bash
ssh ubnt@<cloud-key-ip>
```

## Why Bookworm Is Not Supported

Bookworm (Debian 12) is incompatible with UCK Gen1 hardware. Bullseye
(Debian 11) is the final supported target. See
[BOOKWORM-FINDINGS.md](BOOKWORM-FINDINGS.md) for details.

## Manual Recovery

If the automated upgrade fails partway through, you can manually advance to the next stage:

1. Edit `/etc/apt/sources.list` to contain the correct mirrors for your current release
2. Append the next release name as a comment (e.g., `# buster`)
3. Reboot, or run `sudo bash ~/UCK/bin/uck-upgrade` directly

## Skipping a Stage

If you need to skip a stage (not recommended), edit the state marker:

```bash
# Example: skip from stretch directly to buster
echo "# buster" >> /etc/apt/sources.list
sudo reboot
```

**Warning**: Skipping stages may leave the system in an inconsistent state.
