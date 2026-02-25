# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| main    | ✅ Yes    |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it
responsibly.

**Do NOT file a public issue.** Instead, use one of these methods:

1. **GitHub private vulnerability reporting** — go to the
   [Security tab](https://github.com/msutara/uck-gen1/security/advisories/new)
   and click "Report a vulnerability"
2. **Email** — contact the maintainer directly at the email listed on their
   [GitHub profile](https://github.com/msutara)

### What to include

- Description of the vulnerability
- Steps to reproduce
- Affected files or components
- Potential impact (e.g., privilege escalation, data loss)

### Response timeline

- **Acknowledgement**: within 48 hours
- **Initial assessment**: within 1 week
- **Fix or mitigation**: best effort, typically within 2 weeks

## Scope

This tool runs as **root** on embedded hardware and modifies system packages,
`/etc/apt/sources.list`, `/etc/rc.local`, and SSH configuration. Security
issues in any of these areas are in scope.

Out of scope:

- Vulnerabilities in upstream Debian packages
- Issues specific to UniFi firmware (report to Ubiquiti)
