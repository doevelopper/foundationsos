#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# pre-build.sh — Common pre-build hook
# Invoked via: BR2_ROOTFS_PRE_BUILD_SCRIPT
#
# Buildroot calls this script before any package is built.
# Receives the following positional arguments:
#   $1 ... - Extra arguments from BR2_ROOTFS_PRE_BUILD_SCRIPT_ARGS (if any)
#
# Standard Buildroot environment variables available:
#   HOST_DIR     - host sysroot ($(O)/host)
#   STAGING_DIR  - staging sysroot
#   TARGET_DIR   - target rootfs staging directory
#   BUILD_DIR    - per-package build trees ($(O)/build)
#   BINARIES_DIR - final images output directory ($(O)/images)
#   BASE_DIR     - output base directory ($(O))

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
BOARD_COMMON_DIR="$(cd "$(dirname "$0")" && pwd)"

log() {
    echo "[${SCRIPT_NAME}] $*"
}

log "--- Pre-Build Hook: START ---"
log "HOST_DIR     = ${HOST_DIR:-<unset>}"
log "STAGING_DIR  = ${STAGING_DIR:-<unset>}"
log "TARGET_DIR   = ${TARGET_DIR:-<unset>}"
log "BUILD_DIR    = ${BUILD_DIR:-<unset>}"
log "BINARIES_DIR = ${BINARIES_DIR:-<unset>}"
log "Extra args   = $*"

# ---------------------------------------------------------------------------
# TODO: Add pre-build preparation steps here, for example:
#   - Validate host-side tool availability
#   - Generate version metadata files used during package builds
#   - Fetch or verify signing keys / certificates
#   - Enforce policy checks before a long build starts
# ---------------------------------------------------------------------------

log "--- Pre-Build Hook: DONE ---"
