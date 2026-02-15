#!/bin/bash
# Bookworm (Debian 12) — NOT SUPPORTED on UCK Gen1
#
# The UCK Gen1 uses an AUFS overlay root filesystem which is incompatible
# with Debian's usrmerge package. Bookworm requires merged /usr (/bin → /usr/bin,
# /sbin → /usr/sbin, /lib → /usr/lib) but AUFS returns EBUSY when attempting
# to rename these top-level directories. Without merged /usr, systemd binaries
# in /bin/ remain at the old version and crash against the new libsystemd-shared,
# rendering the system unbootable after reboot.
#
# See docs/BOOKWORM-FINDINGS.md for detailed field testing results.
#
# This file is kept as a stub so the release module loader does not break.
# The bookworm() function is never called in normal operation.

bookworm() {
    log_error "Bookworm upgrade is not supported on UCK Gen1 (AUFS/usrmerge incompatibility)."
    log_error "See docs/BOOKWORM-FINDINGS.md for details."
    exit 1
}
