#!/usr/bin/env bash
# luks-init.sh — Open (or first-boot provision) the LUKS2 encrypted data partition
#
# Called by luks-data.service on every boot.
#
# First boot (partition not yet LUKS):
#   1. Generate 64-byte random key in /run/luks/ (tmpfs)
#   2. Format /dev/mmcblk0p4 as LUKS2 (aes-xts-plain64, 256-bit)
#   3. Open the LUKS container as "luks-data"
#   4. Create ext4 filesystem on /dev/mapper/luks-data
#   5. Seal the key into the TPM using PCR[0,4,7,8] policy (luks-tpm-seal.sh)
#   6. Shred the runtime key from RAM
#
# Subsequent boots (partition is already LUKS):
#   1. Unseal the key from the TPM (PCR policy must match — firmware unchanged)
#   2. Open the LUKS container as "luks-data"
#   3. Shred the runtime key from RAM
#
# The LUKS container is then mounted by data.mount (/dev/mapper/luks-data → /data).
#
# Recovery:
#   If the TPM PCR policy no longer matches (firmware update changed PCR values),
#   booting will fail to unseal.  Use the recovery procedure in ADR-0009:
#   boot a trusted recovery image, use tpm-provision.sh to re-seal with new PCRs.

set -euo pipefail

DEVICE="${LUKS_DEVICE:-/dev/mmcblk0p4}"
MAPPER_NAME="luks-data"
MAPPER_DEV="/dev/mapper/${MAPPER_NAME}"

KEY_RUNTIME_DIR="/run/luks"
KEY_FILE="${KEY_RUNTIME_DIR}/data.key"
SEAL_SCRIPT="/usr/sbin/luks-tpm-seal.sh"

log()  { echo "[luks-init] $*"; }
die()  { echo "[luks-init] ERROR: $*" >&2; exit 1; }

# Ensure the runtime key directory exists on tmpfs (disappears after reboot)
mkdir -p "${KEY_RUNTIME_DIR}"
chmod 700 "${KEY_RUNTIME_DIR}"

# ─── Guards ───────────────────────────────────────────────────────────────────
if [[ -b "${MAPPER_DEV}" ]]; then
    log "${MAPPER_DEV} already open, nothing to do."
    exit 0
fi

[[ -b "${DEVICE}" ]] || die "Data partition not found: ${DEVICE}"

is_luks() {
    cryptsetup isLuks "${DEVICE}" 2>/dev/null
}

# ─── First-boot provisioning ─────────────────────────────────────────────────
provision_luks() {
    log "First boot: provisioning LUKS2 on ${DEVICE}"
    log "  cipher    : aes-xts-plain64"
    log "  key-size  : 256 bits"
    log "  iter-time : 2000 ms"

    # Generate a cryptographically random 64-byte passphrase
    dd if=/dev/urandom bs=64 count=1 of="${KEY_FILE}" 2>/dev/null
    chmod 600 "${KEY_FILE}"

    log "Formatting ${DEVICE} as LUKS2..."
    cryptsetup luksFormat \
        --type luks2 \
        --cipher aes-xts-plain64 \
        --key-size 256 \
        --hash sha256 \
        --iter-time 2000 \
        --pbkdf argon2id \
        --key-file "${KEY_FILE}" \
        --batch-mode \
        "${DEVICE}"

    log "Opening LUKS container as '${MAPPER_NAME}'..."
    cryptsetup luksOpen \
        --key-file "${KEY_FILE}" \
        "${DEVICE}" "${MAPPER_NAME}"

    log "Creating ext4 filesystem on ${MAPPER_DEV}..."
    mkfs.ext4 \
        -L data \
        -E lazy_itable_init=0,lazy_journal_init=0 \
        "${MAPPER_DEV}"

    log "Sealing LUKS key to TPM PCR[0,4,7,8] policy..."
    "${SEAL_SCRIPT}" seal "${KEY_FILE}"

    # Shred the runtime key — it is now sealed inside the TPM
    shred -u "${KEY_FILE}" 2>/dev/null || rm -f "${KEY_FILE}"

    log "✅ Data partition provisioned and key sealed to TPM."
    log "   PCR policy: sha256:0,4,7,8"
    log "   Sealed at:  /etc/tpm2/luks-data.{pub,priv}"
}

# ─── Normal-boot open ─────────────────────────────────────────────────────────
open_luks() {
    log "Unsealing LUKS key from TPM (PCR policy: sha256:0,4,7,8)..."
    "${SEAL_SCRIPT}" unseal "${KEY_FILE}" || \
        die "TPM unseal failed. Firmware may have changed. See ADR-0009 for recovery."

    log "Opening LUKS container on ${DEVICE}..."
    cryptsetup luksOpen \
        --key-file "${KEY_FILE}" \
        "${DEVICE}" "${MAPPER_NAME}"

    # Shred runtime key immediately; LUKS device is now mapped
    shred -u "${KEY_FILE}" 2>/dev/null || rm -f "${KEY_FILE}"

    log "✅ ${MAPPER_DEV} open."
}

# ─── Main ─────────────────────────────────────────────────────────────────────
if ! is_luks; then
    provision_luks
else
    open_luks
fi
