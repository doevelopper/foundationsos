#!/usr/bin/env bash
# tpm-provision.sh — FoundationsOS TPM 2.0 provisioning script
#
# Creates the complete TPM key hierarchy required for:
#   - Attestation (AIK / Attestation Identity Key)
#   - Sealing (for future LUKS key sealing in v0.5.0)
#   - Platform endorsement verification
#
# Prerequisites:
#   - tpm2-tss, tpm2-tools installed
#   - tpm2-abrmd running (or --tcti=device:/dev/tpm0 for direct access)
#   - TPM in a clear/provisioned state (not owned or freshly cleared)
#
# Usage:
#   sudo ./scripts/tpm-provision.sh [--tcti <tcti-string>] [--out-dir <dir>]
#
# Outputs written to OUT_DIR (default: /etc/foundationsos/tpm/):
#   ek.pub          — Endorsement Key public area (RSA-2048)
#   srk.ctx         — Storage Root Key context (persistent handle 0x81000001)
#   aik.ctx         — Attestation Identity Key context (persistent handle 0x81000002)
#   aik.pub         — AIK public area (for remote verifier)
#   sealing.ctx     — Sealing key context (persistent handle 0x81000003)
#   pcr-policy.dat  — PCR[0,4,7,8] policy digest for sealing
#
# WARNING: Running this script clears any existing keys at handles 0x81000001-3.

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
TCTI="${TPM2TOOLS_TCTI:-tabrmd:bus_name=com.intel.tss2.Tabrmd}"
OUT_DIR="${TPM_OUT_DIR:-/etc/foundationsos/tpm}"
# PCRs to include in sealing policy: U-Boot(0), kernel(4), DTB(7), slot(8)
PCR_LIST="0,4,7,8"
PCR_BANK="sha256"

# Persistent handles
HANDLE_SRK="0x81000001"
HANDLE_AIK="0x81000002"
HANDLE_SEALING="0x81000003"

# ─── Helpers ─────────────────────────────────────────────────────────────────
log()  { echo "[tpm-provision] $*"; }
die()  { echo "[tpm-provision] ERROR: $*" >&2; exit 1; }

require_cmd() {
    command -v "$1" &>/dev/null || die "'$1' not found. Install tpm2-tools."
}

# ─── Preflight ────────────────────────────────────────────────────────────────
require_cmd tpm2_createek
require_cmd tpm2_createprimary
require_cmd tpm2_create
require_cmd tpm2_load
require_cmd tpm2_evictcontrol
require_cmd tpm2_pcrread
require_cmd tpm2_createpolicy
require_cmd tpm2_startauthsession

[ "$(id -u)" -eq 0 ] || die "Must run as root."

install -d -m 700 "${OUT_DIR}"
log "Output directory: ${OUT_DIR}"

# ─── Step 1: Create / read Endorsement Key ───────────────────────────────────
log "Step 1: Creating Endorsement Key (RSA-2048)..."
tpm2_createek \
    --tcti="${TCTI}" \
    --ek-context "${OUT_DIR}/ek.ctx" \
    --key-algorithm rsa \
    --public "${OUT_DIR}/ek.pub"
log "  EK public area → ${OUT_DIR}/ek.pub"

# ─── Step 2: Create Storage Root Key (SRK) ───────────────────────────────────
log "Step 2: Creating Storage Root Key (RSA-2048, primary, owner hierarchy)..."
tpm2_createprimary \
    --tcti="${TCTI}" \
    --hierarchy owner \
    --key-algorithm rsa2048:null:aes128cfb \
    --key-context "${OUT_DIR}/srk.ctx"

# Persist SRK so it survives power cycles
tpm2_evictcontrol \
    --tcti="${TCTI}" \
    --hierarchy owner \
    --object-context "${OUT_DIR}/srk.ctx" \
    "${HANDLE_SRK}" 2>/dev/null || \
tpm2_evictcontrol \
    --tcti="${TCTI}" \
    --hierarchy owner \
    --object-context "${HANDLE_SRK}" \
    "${HANDLE_SRK}"
log "  SRK persisted at ${HANDLE_SRK}"

# ─── Step 3: Create Attestation Identity Key (AIK) ───────────────────────────
log "Step 3: Creating Attestation Identity Key (ECC P-256, restricted signing)..."
tpm2_create \
    --tcti="${TCTI}" \
    --parent-context "${HANDLE_SRK}" \
    --key-algorithm ecc256:ecdsa-sha256:null \
    --attributes "fixedtpm|fixedparent|sensitivedataorigin|userwithauth|sign|restricted" \
    --public "${OUT_DIR}/aik.pub" \
    --private "${OUT_DIR}/aik.priv"

tpm2_load \
    --tcti="${TCTI}" \
    --parent-context "${HANDLE_SRK}" \
    --public "${OUT_DIR}/aik.pub" \
    --private "${OUT_DIR}/aik.priv" \
    --key-context "${OUT_DIR}/aik.ctx"

tpm2_evictcontrol \
    --tcti="${TCTI}" \
    --hierarchy owner \
    --object-context "${OUT_DIR}/aik.ctx" \
    "${HANDLE_AIK}" 2>/dev/null || \
tpm2_evictcontrol \
    --tcti="${TCTI}" \
    --hierarchy owner \
    --object-context "${HANDLE_AIK}" \
    "${HANDLE_AIK}"
log "  AIK public key  → ${OUT_DIR}/aik.pub"
log "  AIK persisted at ${HANDLE_AIK}"

# ─── Step 4: Read current PCR values and create sealing policy ───────────────
log "Step 4: Reading PCR[${PCR_LIST}] (${PCR_BANK}) for sealing policy..."
tpm2_pcrread \
    --tcti="${TCTI}" \
    "${PCR_BANK}:${PCR_LIST}" \
    --output "${OUT_DIR}/pcr-values.bin"
tpm2_pcrread \
    --tcti="${TCTI}" \
    "${PCR_BANK}:${PCR_LIST}"

log "Step 4b: Creating PCR policy digest..."
tpm2_startauthsession \
    --tcti="${TCTI}" \
    --session "${OUT_DIR}/session.ctx"
tpm2_policypcr \
    --tcti="${TCTI}" \
    --session "${OUT_DIR}/session.ctx" \
    --pcr-list "${PCR_BANK}:${PCR_LIST}" \
    --policy "${OUT_DIR}/pcr-policy.dat"
tpm2_flushcontext \
    --tcti="${TCTI}" \
    "${OUT_DIR}/session.ctx" 2>/dev/null || true
log "  PCR policy digest → ${OUT_DIR}/pcr-policy.dat"

# ─── Step 5: Create Sealing Key (for v0.5.0 LUKS key sealing) ───────────────
log "Step 5: Creating Sealing Key (sealed to PCR policy)..."
tpm2_create \
    --tcti="${TCTI}" \
    --parent-context "${HANDLE_SRK}" \
    --key-algorithm keyedhash:null \
    --attributes "fixedtpm|fixedparent|adminwithpolicy" \
    --policy "${OUT_DIR}/pcr-policy.dat" \
    --public "${OUT_DIR}/sealing.pub" \
    --private "${OUT_DIR}/sealing.priv"

tpm2_load \
    --tcti="${TCTI}" \
    --parent-context "${HANDLE_SRK}" \
    --public "${OUT_DIR}/sealing.pub" \
    --private "${OUT_DIR}/sealing.priv" \
    --key-context "${OUT_DIR}/sealing.ctx"

tpm2_evictcontrol \
    --tcti="${TCTI}" \
    --hierarchy owner \
    --object-context "${OUT_DIR}/sealing.ctx" \
    "${HANDLE_SEALING}" 2>/dev/null || \
tpm2_evictcontrol \
    --tcti="${TCTI}" \
    --hierarchy owner \
    --object-context "${HANDLE_SEALING}" \
    "${HANDLE_SEALING}"
log "  Sealing key persisted at ${HANDLE_SEALING}"

# ─── Step 6: Cleanup sensitive files ─────────────────────────────────────────
rm -f "${OUT_DIR}/aik.priv" \
      "${OUT_DIR}/sealing.priv" \
      "${OUT_DIR}/session.ctx" \
      "${OUT_DIR}/ek.ctx" \
      "${OUT_DIR}/srk.ctx" \
      "${OUT_DIR}/aik.ctx" \
      "${OUT_DIR}/sealing.ctx"
chmod 400 "${OUT_DIR}/ek.pub" "${OUT_DIR}/aik.pub" "${OUT_DIR}/pcr-policy.dat"
chmod 400 "${OUT_DIR}/sealing.pub" "${OUT_DIR}/pcr-values.bin"

log ""
log "TPM provisioning complete."
log "  EK public:       ${OUT_DIR}/ek.pub"
log "  AIK public:      ${OUT_DIR}/aik.pub  (share with remote verifier)"
log "  PCR policy:      ${OUT_DIR}/pcr-policy.dat"
log "  SRK handle:      ${HANDLE_SRK}"
log "  AIK handle:      ${HANDLE_AIK}"
log "  Sealing handle:  ${HANDLE_SEALING}"
log ""
log "Next: run tpm-attest.sh to generate attestation evidence."
