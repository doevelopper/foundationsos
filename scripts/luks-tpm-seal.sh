#!/usr/bin/env bash
# luks-tpm-seal.sh — Seal/unseal a LUKS key into the TPM2
#
# The LUKS data-partition key is sealed to a new TPM2 data-object stored under
# the SRK (0x81000001, provisioned in v0.3.0).  The object's authorization
# policy binds to PCR[0,4,7,8]; any firmware change will prevent unsealing.
#
# Sealed object files are stored at:
#   /etc/tpm2/luks-data.pub   — public area of the sealed object
#   /etc/tpm2/luks-data.priv  — encrypted private area (can be stored on-disk)
#
# Usage:
#   luks-tpm-seal.sh seal   <keyfile>          # encrypt + seal key to TPM
#   luks-tpm-seal.sh unseal <output-keyfile>   # unseal key from TPM → file
#
# Prerequisites:
#   - tpm2-abrmd running  (TCTI: tabrmd:bus_name=com.intel.tss2.Tabrmd)
#   - SRK persisted at 0x81000001 (run scripts/tpm-provision.sh first)

set -euo pipefail

TCTI="${TPM2TOOLS_TCTI:-tabrmd:bus_name=com.intel.tss2.Tabrmd}"
TPM_SRK_HANDLE="0x81000001"
PCR_BANK="sha256"
PCR_LIST="0,4,7,8"

SEALED_DIR="${TPM_SEALED_DIR:-/etc/tpm2}"
SEALED_PUB="${SEALED_DIR}/luks-data.pub"
SEALED_PRIV="${SEALED_DIR}/luks-data.priv"

# Temporary session/context files
SESSION_CTX=$(mktemp /tmp/tpm2-seal-session.XXXXXX.ctx)
LOADED_CTX=$(mktemp /tmp/tpm2-loaded-obj.XXXXXX.ctx)

cleanup() {
    tpm2_flushcontext --tcti="${TCTI}" "${SESSION_CTX}" 2>/dev/null || true
    tpm2_flushcontext --tcti="${TCTI}" "${LOADED_CTX}" 2>/dev/null || true
    rm -f "${SESSION_CTX}" "${LOADED_CTX}"
}
trap cleanup EXIT

log()  { echo "[luks-tpm-seal] $*"; }
die()  { echo "[luks-tpm-seal] ERROR: $*" >&2; exit 1; }

# ─── seal ─────────────────────────────────────────────────────────────────────
do_seal() {
    local keyfile="$1"
    [[ -f "${keyfile}" ]] || die "keyfile not found: ${keyfile}"
    [[ $(stat -c%s "${keyfile}") -gt 0 ]] || die "keyfile is empty"

    mkdir -p "${SEALED_DIR}"
    chmod 700 "${SEALED_DIR}"

    log "Creating PCR[${PCR_LIST}] policy session..."
    tpm2_startauthsession \
        --tcti="${TCTI}" \
        --session "${SESSION_CTX}" \
        --policy-session

    tpm2_policypcr \
        --tcti="${TCTI}" \
        --session "${SESSION_CTX}" \
        --pcr-list "${PCR_BANK}:${PCR_LIST}"

    log "Sealing key under SRK (${TPM_SRK_HANDLE})..."
    tpm2_create \
        --tcti="${TCTI}" \
        --parent-context "${TPM_SRK_HANDLE}" \
        --sealing-input "${keyfile}" \
        --policy "${SESSION_CTX}" \
        --key-algorithm keyedhash \
        --hash-algorithm sha256 \
        --attributes "fixedtpm|fixedparent|noda|adminwithpolicy" \
        --public "${SEALED_PUB}" \
        --private "${SEALED_PRIV}"

    chmod 600 "${SEALED_PUB}" "${SEALED_PRIV}"
    log "✅ Key sealed → ${SEALED_PUB} / ${SEALED_PRIV}"
}

# ─── unseal ───────────────────────────────────────────────────────────────────
do_unseal() {
    local output="$1"
    local outdir
    outdir="$(dirname "${output}")"

    [[ -f "${SEALED_PUB}" ]]  || die "Sealed public not found: ${SEALED_PUB}  (run 'seal' first)"
    [[ -f "${SEALED_PRIV}" ]] || die "Sealed private not found: ${SEALED_PRIV} (run 'seal' first)"

    mkdir -p "${outdir}"
    chmod 700 "${outdir}"

    log "Creating PCR[${PCR_LIST}] policy session for unseal..."
    tpm2_startauthsession \
        --tcti="${TCTI}" \
        --session "${SESSION_CTX}" \
        --policy-session

    tpm2_policypcr \
        --tcti="${TCTI}" \
        --session "${SESSION_CTX}" \
        --pcr-list "${PCR_BANK}:${PCR_LIST}"

    log "Loading sealed object under SRK..."
    tpm2_load \
        --tcti="${TCTI}" \
        --parent-context "${TPM_SRK_HANDLE}" \
        --public "${SEALED_PUB}" \
        --private "${SEALED_PRIV}" \
        --key-context "${LOADED_CTX}"

    log "Unsealing key from TPM..."
    tpm2_unseal \
        --tcti="${TCTI}" \
        --object-context "${LOADED_CTX}" \
        --auth "session:${SESSION_CTX}" \
        --output "${output}"

    chmod 600 "${output}"
    log "✅ Key unsealed → ${output}"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
case "${1:-}" in
    seal)   do_seal   "${2:?'Usage: luks-tpm-seal.sh seal <keyfile>'}" ;;
    unseal) do_unseal "${2:?'Usage: luks-tpm-seal.sh unseal <output-keyfile>'}" ;;
    *)
        echo "Usage: $0 {seal <keyfile> | unseal <output-keyfile>}"
        echo ""
        echo "  seal   <keyfile>         Seal keyfile into TPM2 under SRK, bound to PCR[${PCR_LIST}]"
        echo "  unseal <output-keyfile>  Unseal key from TPM2 → output-keyfile (requires matching PCRs)"
        exit 1 ;;
esac
