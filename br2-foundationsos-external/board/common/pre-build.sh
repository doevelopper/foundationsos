#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# pre-build.sh — Common pre-build hook
# Invoked via: BR2_ROOTFS_PRE_BUILD_SCRIPT
#
# Buildroot calls this script before any package is built.
#
# Calling convention (Buildroot 2026.02+):
#   $1       - TARGET_DIR (populated rootfs staging directory)
#   $2..n    - BR2_ROOTFS_POST_SCRIPT_ARGS   (shared with all hooks)
#              then BR2_ROOTFS_PRE_BUILD_SCRIPT_ARGS (pre-build-specific)
#
# Recognised named arguments (passed via BR2_ROOTFS_POST_SCRIPT_ARGS):
#   --board-gen=N   Board generation number
#                   e.g.  BR2_ROOTFS_POST_SCRIPT_ARGS="--board-gen=5"
#
# Standard Buildroot environment variables available:
#   HOST_DIR     - host sysroot        ($(O)/host)
#   STAGING_DIR  - staging sysroot
#   TARGET_DIR   - target rootfs       (also $1)
#   BUILD_DIR    - per-package builds  ($(O)/build)
#   BINARIES_DIR - final images        ($(O)/images)
#   BASE_DIR     - output base         ($(O))
#   BR2_EXTERNAL_FOUNDATIONSOS_PATH - path to this external tree

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
BOARD_COMMON_DIR="$(cd "$(dirname "$0")" && pwd)"

TARGET_DIR="${1:?TARGET_DIR argument is required}"
shift   # $@ now contains BR2_ROOTFS_POST_SCRIPT_ARGS + BR2_ROOTFS_PRE_BUILD_SCRIPT_ARGS

log() { echo "[${SCRIPT_NAME}] $*"; }

# ---------------------------------------------------------------------------
# Parse named arguments
# ---------------------------------------------------------------------------
BOARD_GEN=""
for arg in "$@"; do
    case "${arg}" in
        --board-gen=*) BOARD_GEN="${arg#--board-gen=}" ;;
    esac
done

log "--- Pre-Build Hook: START ---"
log "HOST_DIR     = ${HOST_DIR:-<unset>}"
log "STAGING_DIR  = ${STAGING_DIR:-<unset>}"
log "TARGET_DIR   = ${TARGET_DIR}"
log "BUILD_DIR    = ${BUILD_DIR:-<unset>}"
log "BINARIES_DIR = ${BINARIES_DIR:-<unset>}"
log "BOARD_GEN    = ${BOARD_GEN:-<not set>}"
log "Extra args   = $*"

# ---------------------------------------------------------------------------
# TODO: Add pre-build preparation steps here, for example:
#   - Validate host-side tool availability
#   - Generate version metadata files used during package builds
#   - Fetch or verify signing keys / certificates
#   - Enforce policy checks before a long build starts
# ---------------------------------------------------------------------------

log "--- Pre-Build Hook: DONE ---"
