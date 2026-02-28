#!/usr/bin/env bash
# post-build.sh — Raspberry Pi 3B+ board-specific post-build hook.
# Executed by Buildroot after the root filesystem is assembled
# but before the filesystem image is created.
#
# $1 = TARGET_DIR  (staged root filesystem)

set -euo pipefail

TARGET_DIR="${1}"
BOARD_DIR="$(dirname "$0")"

echo "[post-build] Hardening root filesystem (raspberrypi3bp)..."

# ─── Disable root login via getty ─────────────────────────────────────────────
install -D -m 644 /dev/null "${TARGET_DIR}/etc/securetty"

# ─── Remove dangerous SUID bits ───────────────────────────────────────────────
for f in su ping mount umount; do
    if [ -f "${TARGET_DIR}/usr/bin/${f}" ]; then
        chmod u-s "${TARGET_DIR}/usr/bin/${f}" || true
    fi
done

# ─── Install RAUC system configuration ────────────────────────────────────────
if [ -d "${BOARD_DIR}/rootfs_overlay/etc/rauc" ]; then
    cp -r "${BOARD_DIR}/rootfs_overlay/etc/rauc/." "${TARGET_DIR}/etc/rauc/"
fi

# ─── Install boot configuration ───────────────────────────────────────────────
# config.txt and cmdline.txt are installed via the rootfs overlay onto the
# boot FAT partition by genimage; no extra action needed here.

# ─── Set restrictive permissions on sensitive files ───────────────────────────
chmod 600 "${TARGET_DIR}/etc/shadow"    2>/dev/null || true
chmod 600 "${TARGET_DIR}/etc/gshadow"   2>/dev/null || true
chmod 644 "${TARGET_DIR}/etc/passwd"    2>/dev/null || true
chmod 644 "${TARGET_DIR}/etc/group"     2>/dev/null || true

# ─── IMA policy ───────────────────────────────────────────────────────────────
if [ -f "${BOARD_DIR}/rootfs_overlay/etc/ima/ima-policy" ]; then
    install -D -m 644 \
        "${BOARD_DIR}/rootfs_overlay/etc/ima/ima-policy" \
        "${TARGET_DIR}/etc/ima/ima-policy"
fi

echo "[post-build] Root filesystem hardening complete (raspberrypi3bp)."
