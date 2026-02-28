#!/usr/bin/env bash
# post-image.sh — Executed by Buildroot after the filesystem images are created.
# Copies boot overlay files into BINARIES_DIR, validates TF-A + OP-TEE binaries,
# compiles the U-Boot boot script, then invokes genimage to assemble the SD image.
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

# ─── Copy board-specific boot files into BINARIES_DIR ─────────────────────────
# genimage reads all boot partition files from BINARIES_DIR (inputpath).
for f in config.txt cmdline.txt; do
    src="${BOARD_DIR}/rootfs_overlay/boot/${f}"
    if [ -f "${src}" ]; then
        cp -f "${src}" "${BINARIES_DIR}/${f}"
        echo "[post-image] Copied ${f} → BINARIES_DIR"
    fi
done

# ─── Validate TF-A BL31 binary ────────────────────────────────────────────────
# bl31.bin is produced by the arm-trusted-firmware Buildroot package.
# It is loaded by the VideoCore firmware as an armstub (EL3 entry point).
if [ -f "${BINARIES_DIR}/bl31.bin" ]; then
    echo "[post-image] TF-A bl31.bin found ($(du -h "${BINARIES_DIR}/bl31.bin" | cut -f1))"
else
    echo "[post-image] WARNING: bl31.bin not found in BINARIES_DIR."
    echo "[post-image]          Ensure BR2_TARGET_ARM_TRUSTED_FIRMWARE=y is set."
fi

# ─── Validate OP-TEE binaries ────────────────────────────────────────────────
# OP-TEE produces three image files (paged OP-TEE format).
# They must all be present in BINARIES_DIR before genimage runs.
optee_ok=true
for tee_bin in tee-header_v2.bin tee-pager_v2.bin tee-pageable_v2.bin; do
    if [ -f "${BINARIES_DIR}/${tee_bin}" ]; then
        echo "[post-image] OP-TEE ${tee_bin} found ($(du -h "${BINARIES_DIR}/${tee_bin}" | cut -f1))"
    else
        echo "[post-image] WARNING: ${tee_bin} not found in BINARIES_DIR."
        optee_ok=false
    fi
done
if [ "${optee_ok}" = "false" ]; then
    echo "[post-image]          Ensure BR2_TARGET_OPTEE_OS=y is set."
fi

# ─── Compile U-Boot boot script ───────────────────────────────────────────────
BOOT_CMD="${BOARD_DIR}/rootfs_overlay/boot/boot.cmd"
BOOT_SCR="${BINARIES_DIR}/boot.scr"
if [ -f "${BOOT_CMD}" ]; then
    if command -v mkimage &>/dev/null; then
        mkimage -C none -A arm64 -T script -d "${BOOT_CMD}" "${BOOT_SCR}"
        echo "[post-image] Compiled boot.scr from boot.cmd"
    else
        echo "[post-image] WARNING: 'mkimage' not found. boot.scr not compiled."
        echo "[post-image]          Install u-boot-tools on the host or enable BR2_PACKAGE_HOST_UBOOT_TOOLS."
    fi
fi

echo "[post-image] Generating disk image (raspberrypi5)..."

rm -rf "${GENIMAGE_TMP}"
genimage \
    --rootpath "${TARGET_DIR}" \
    --tmppath  "${GENIMAGE_TMP}" \
    --inputpath "${BINARIES_DIR}" \
    --outputpath "${BINARIES_DIR}" \
    --config "${GENIMAGE_CFG}"

echo "[post-image] SD card image: ${BINARIES_DIR}/sdcard.img"

sha256sum "${BINARIES_DIR}/sdcard.img" > "${BINARIES_DIR}/sdcard.img.sha256"
echo "[post-image] Checksum: ${BINARIES_DIR}/sdcard.img.sha256"
