#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# post-fakeroot.sh — Common post-fakeroot hook
# Invoked via: BR2_ROOTFS_POST_FAKEROOT_SCRIPT
#
# Buildroot calls this script *inside a fakeroot environment* after the
# post-build scripts finish but before any filesystem image is created.
# Running inside fakeroot means the script can safely manipulate file
# ownership and special-file permissions (devices, setuid bits) as if it
# were truly root, without requiring host-side privileges.
#
# Receives the following positional arguments:
#   $1       - TARGET_DIR (populated rootfs staging directory)
#   $2 ...   - Extra arguments from BR2_ROOTFS_POST_SCRIPT_ARGS
#
# Standard Buildroot environment variables available:
#   HOST_DIR     - host sysroot ($(O)/host)
#   STAGING_DIR  - staging sysroot
#   TARGET_DIR   - target rootfs staging directory  (also $1)
#   BUILD_DIR    - per-package build trees ($(O)/build)
#   BINARIES_DIR - final images output directory ($(O)/images)
#   BASE_DIR     - output base directory ($(O))
#
# NOTE: Inside fakeroot, standard host commands (e.g. chown, chmod, mknod)
# operate on the fakeroot database, not the real host filesystem.

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
BOARD_COMMON_DIR="$(cd "$(dirname "$0")" && pwd)"

TARGET_DIR="${1:?TARGET_DIR argument is required}"
shift         # remaining positional args come from BR2_ROOTFS_POST_SCRIPT_ARGS

log() {
    echo "[${SCRIPT_NAME}] $*"
}

log "--- Post-Fakeroot Hook: START ---"
log "TARGET_DIR   = ${TARGET_DIR}"
log "BINARIES_DIR = ${BINARIES_DIR:-<unset>}"
log "Extra args   = $*"

# ---------------------------------------------------------------------------
# TODO: Add fakeroot-privileged rootfs finalization steps here, for example:
#   - Set correct ownership on /etc/shadow (root:shadow 640)
#   - Create device nodes not covered by devices-table.conf
#   - Apply setuid/setgid bits to binaries that require them
#   - Seal IMA/EVM hashes that need root ownership on signed files
#   - Create /dev/console or other minimal device entries if needed
# ---------------------------------------------------------------------------

log "--- Post-Fakeroot Hook: DONE ---"
