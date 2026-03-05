#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# post-build.sh — Common post-build hook
# Invoked via: BR2_ROOTFS_POST_BUILD_SCRIPT
#
# Buildroot calls this script after all packages have been installed into
# TARGET_DIR but before any filesystem image is generated.
# Multiple scripts can be listed (space-separated); this is the common one
# that runs for every board variant.
#
# Receives the following positional arguments:
#   $1       - TARGET_DIR (populated rootfs staging directory)
#   $2 ...   - Extra arguments from BR2_ROOTFS_POST_BUILD_SCRIPT_ARGS
#
# Standard Buildroot environment variables available:
#   HOST_DIR     - host sysroot ($(O)/host)
#   STAGING_DIR  - staging sysroot
#   TARGET_DIR   - target rootfs staging directory  (also $1)
#   BUILD_DIR    - per-package build trees ($(O)/build)
#   BINARIES_DIR - final images output directory ($(O)/images)
#   BASE_DIR     - output base directory ($(O))

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
BOARD_COMMON_DIR="$(cd "$(dirname "$0")" && pwd)"

TARGET_DIR="${1:?TARGET_DIR argument is required}"
shift         # remaining positional args come from BR2_ROOTFS_POST_BUILD_SCRIPT_ARGS

log() {
    echo "[${SCRIPT_NAME}] $*"
}

log "--- Post-Build Hook: START ---"
log "TARGET_DIR   = ${TARGET_DIR}"
log "BINARIES_DIR = ${BINARIES_DIR:-<unset>}"
log "Extra args   = $*"

# ---------------------------------------------------------------------------
# TODO: Add TARGET_DIR customisation steps here, for example:
#   - Remove development artifacts (headers, static libs, man pages)
#   - Harden filesystem permissions on sensitive files/directories
#   - Embed build-time version/commit metadata into /etc/os-release
#   - Apply common overlays or skeletal configuration files
#   - Run policy/compliance checks against the staged rootfs
# ---------------------------------------------------------------------------

log "--- Post-Build Hook: DONE ---"
