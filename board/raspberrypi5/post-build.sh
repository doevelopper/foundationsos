#!/usr/bin/env bash
# post-build.sh — Executed by Buildroot after the root filesystem is assembled
# but before the filesystem image is created.
#
# $1 = TARGET_DIR  (path to the staged root filesystem)
# $2 = BUILD_DIR   (Buildroot build directory)
# $3 = STAGING_DIR
# $4 = HOST_DIR

set -euo pipefail

TARGET_DIR="${1}"
BOARD_DIR="$(dirname "$0")"

echo "[post-build] Hardening root filesystem..."

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

# ─── LUKS / encrypted data partition (v0.5.0) ────────────────────────────────
# Create /data mountpoint for the LUKS-encrypted data partition.
# The actual LUKS formatting and TPM key sealing happen on first boot via
# luks-data.service → luks-init.sh.
mkdir -p "${TARGET_DIR}/data"
chmod 750 "${TARGET_DIR}/data"

# Install LUKS helper scripts to /usr/sbin/
install -D -m 750 "${BOARD_DIR}/../../scripts/luks-init.sh" \
    "${TARGET_DIR}/usr/sbin/luks-init.sh"
install -D -m 750 "${BOARD_DIR}/../../scripts/luks-tpm-seal.sh" \
    "${TARGET_DIR}/usr/sbin/luks-tpm-seal.sh"

# Create /etc/tpm2 directory for sealed key storage
mkdir -p "${TARGET_DIR}/etc/tpm2"
chmod 700 "${TARGET_DIR}/etc/tpm2"

echo "[post-build] Root filesystem hardening complete."
