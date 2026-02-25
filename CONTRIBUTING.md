# Contributing to uck-gen1

Thanks for your interest in improving the UCK Gen1 upgrade tool! This document
explains how to contribute effectively.

## Getting Started

1. Fork the repository
2. Clone your fork
3. Create a feature branch from `main`

```bash
git checkout -b feat/my-change main
```

## Development Guidelines

### Shell scripting conventions

- All scripts must pass `shellcheck --severity=warning`
- Use `[[ ]]` for conditionals (not `[ ]`)
- Use `$()` for command substitution (not backticks)
- All awk patterns must use `[ \t]` (not `[[:space:]]`) for mawk
  compatibility on Jessie
- Use `[[:blank:]]` in grep regexes for POSIX portability
- All destructive commands must go through the `run` wrapper so `--dry-run`
  works
- Non-critical commands use `run_optional` (allows failure without aborting)

### Line endings

The repository enforces LF line endings via `.gitattributes`. If you're on
Windows, ensure `core.autocrlf` is set to `true` or `input`.

### Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

```txt
feat: add new feature
fix: correct bug in stretch stage
docs: update troubleshooting guide
chore: update CI workflow
```

## Testing

### ShellCheck

```bash
find . -type f \( -name '*.sh' -o -name 'uck-upgrade' \) -print0 \
  | xargs -0 shellcheck --severity=warning
```

### Dry-run smoke test

```bash
sudo bash tests/dry-run-smoke.sh
```

### Dry-run mode

Preview what the tool would do without making changes:

```bash
sudo bash ~/UCK/bin/uck-upgrade --dry-run
```

## Pull Request Process

1. Ensure shellcheck passes with zero warnings
2. Ensure the dry-run smoke test passes
3. Update documentation if your change affects user-facing behavior
4. Fill out the PR template completely
5. Wait for CI to pass and maintainer review

## Hardware Notes

- **Target hardware**: Ubiquiti UniFi Cloud Key Gen1 only
- **Root filesystem**: AUFS overlay — `mv` on top-level dirs returns EBUSY
- **Final target**: Bullseye (Debian 11) — Bookworm is
  [incompatible](docs/BOOKWORM-FINDINGS.md)
- **Oldest environment**: Jessie (Debian 8) with mawk — ensure backward
  compatibility

## Code of Conduct

This project follows the
[Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating,
you agree to abide by its terms.
