#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# post-image.sh — Common post-image hook
# Invoked via: BR2_ROOTFS_POST_IMAGE_SCRIPT
#
# Buildroot calls this script after all filesystem images (rootfs, kernel,
# DTBs, …) have been written to BINARIES_DIR.  This is the right place for
# steps that operate on final images rather than the staged rootfs tree.
#
# Receives the following positional arguments:
#   $1       - BINARIES_DIR (final images output directory)
#   $2 ...   - Extra arguments from BR2_ROOTFS_POST_IMAGE_SCRIPT_ARGS
#
# Standard Buildroot environment variables available:
#   HOST_DIR     - host sysroot ($(O)/host)
#   STAGING_DIR  - staging sysroot
#   TARGET_DIR   - target rootfs staging directory
#   BUILD_DIR    - per-package build trees ($(O)/build)
#   BINARIES_DIR - final images output directory ($(O)/images)  (also $1)
#   BASE_DIR     - output base directory ($(O))

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
BOARD_COMMON_DIR="$(cd "$(dirname "$0")" && pwd)"

BINARIES_DIR="${1:?BINARIES_DIR argument is required}"
shift         # remaining positional args come from BR2_ROOTFS_POST_IMAGE_SCRIPT_ARGS

log() {
    echo "[${SCRIPT_NAME}] $*"
}

log "--- Post-Image Hook: START ---"
log "BINARIES_DIR = ${BINARIES_DIR}"
log "Extra args   = $*"

# ---------------------------------------------------------------------------
# TODO: Add post-image steps here, for example:
#   - Sign firmware images (FIT image, RAUC bundle, …)
#   - Generate SBOM / bill-of-materials from image manifests
#   - Compute and record SHA-256 checksums of all deliverables
#   - Copy artefacts to a staging directory for CI upload
#   - Produce OTA update bundles (RAUC, SWUpdate, …)
# ---------------------------------------------------------------------------

log "--- Post-Image Hook: DONE ---"
