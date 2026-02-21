#!/usr/bin/env bash
# post-image.sh — Executed by Buildroot after the filesystem images are created.
# Assembles the final SD card image using genimage.
#
# $1 = BINARIES_DIR (output/images)

set -euo pipefail

BINARIES_DIR="${1}"
BOARD_DIR="$(dirname "$0")"
GENIMAGE_CFG="${BOARD_DIR}/genimage.cfg"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"

# Require genimage host tool
if ! command -v genimage &>/dev/null; then
    echo "[post-image] ERROR: 'genimage' not found. Install it or enable BR2_PACKAGE_HOST_GENIMAGE."
    exit 1
fi

echo "[post-image] Generating disk image..."

rm -rf "${GENIMAGE_TMP}"
genimage \
    --rootpath "${TARGET_DIR}" \
    --tmppath  "${GENIMAGE_TMP}" \
    --inputpath "${BINARIES_DIR}" \
    --outputpath "${BINARIES_DIR}" \
    --config "${GENIMAGE_CFG}"

echo "[post-image] SD card image: ${BINARIES_DIR}/sdcard.img"

# Generate SHA-256 checksum
sha256sum "${BINARIES_DIR}/sdcard.img" > "${BINARIES_DIR}/sdcard.img.sha256"
echo "[post-image] Checksum: ${BINARIES_DIR}/sdcard.img.sha256"
