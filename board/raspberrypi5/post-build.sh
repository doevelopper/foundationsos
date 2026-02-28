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

# ─── IMA/EVM — install runtime scripts (v0.6.0) ──────────────────────────────
install -D -m 750 "${BOARD_DIR}/../../scripts/evm-setup.sh" \
    "${TARGET_DIR}/usr/sbin/evm-setup.sh"

# Sign all root-owned ELF binaries and shared libraries with the IMA key.
# Requires: keys/ima/ima-signing-key.pem (run generate-ima-keys.sh once)
#           host-ima-evm-utils (evmctl) must be in PATH
IMA_SIGN_SCRIPT="${BOARD_DIR}/../../scripts/ima-sign-rootfs.sh"
IMA_KEY="${BOARD_DIR}/../../keys/ima/ima-signing-key.pem"
IMA_CERT="${BOARD_DIR}/../../keys/ima/ima-signing-cert.pem"

if [[ -x "${IMA_SIGN_SCRIPT}" ]] && \
   [[ -f "${IMA_KEY}" ]] && \
   command -v evmctl &>/dev/null; then
    echo "[post-build] Signing rootfs with IMA key..."
    "${IMA_SIGN_SCRIPT}" "${TARGET_DIR}" \
        --key  "${IMA_KEY}" \
        --cert "${IMA_CERT}"
else
    echo "[post-build] WARN: Skipping IMA signing (key or evmctl not found)."
    echo "  Run scripts/generate-ima-keys.sh and ensure host-ima-evm-utils is built."
fi

echo "[post-build] Root filesystem hardening complete."
