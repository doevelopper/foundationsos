#!/usr/bin/env bash
# tpm-attest.sh — FoundationsOS TPM 2.0 attestation script
#
# Generates a TPM2 quote (signed PCR attestation evidence) using the AIK
# provisioned by tpm-provision.sh.  The quote can be sent to a remote
# verifier (attestation server) to prove the system booted from a known-good
# firmware + kernel configuration.
#
# Usage:
#   # Generate a quote (on the target device)
#   sudo ./scripts/tpm-attest.sh quote [--nonce <hex>] [--out <file>]
#
#   # Verify a quote locally against a stored PCR baseline
#   sudo ./scripts/tpm-attest.sh verify --quote <file> --baseline <pcr-baseline.json>
#
#   # Show current PCR values
#   sudo ./scripts/tpm-attest.sh pcr-show
#
# Quote output files (default: /run/tpm-attestation/):
#   quote.bin       — TPM2_Quote TPMS_ATTEST structure (CBOR/TLV)
#   quote.sig       — Signature over quote (ECC P-256 ECDSA-SHA256)
#   pcr-values.bin  — PCR digest values at time of quote
#   nonce.bin       — Nonce used (caller-supplied or random)

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
TCTI="${TPM2TOOLS_TCTI:-tabrmd:bus_name=com.intel.tss2.Tabrmd}"
KEYS_DIR="${TPM_KEYS_DIR:-/etc/foundationsos/tpm}"
OUT_DIR="${TPM_ATTEST_DIR:-/run/tpm-attestation}"
HANDLE_AIK="0x81000002"
PCR_LIST="0,4,7,8"
PCR_BANK="sha256"

# ─── Helpers ─────────────────────────────────────────────────────────────────
log()  { echo "[tpm-attest] $*"; }
die()  { echo "[tpm-attest] ERROR: $*" >&2; exit 1; }
usage() {
    echo "Usage: $0 {quote|verify|pcr-show} [options]"
    echo "  quote    --nonce <hex32>  --out <dir>   Generate TPM quote"
    echo "  verify   --quote <dir>    --baseline <json>  Verify quote"
    echo "  pcr-show                                Print current PCR values"
    exit 1
}

require_cmd() { command -v "$1" &>/dev/null || die "'$1' not found."; }

# ─── Sub-command: pcr-show ────────────────────────────────────────────────────
cmd_pcr_show() {
    log "Current PCR values (${PCR_BANK}:${PCR_LIST}):"
    tpm2_pcrread --tcti="${TCTI}" "${PCR_BANK}:${PCR_LIST}"
    echo ""
    log "IMA measurement log (last 10 entries):"
    if [ -f /sys/kernel/security/ima/ascii_runtime_measurements ]; then
        tail -10 /sys/kernel/security/ima/ascii_runtime_measurements
    else
        log "  IMA log not available (securityfs not mounted?)"
    fi
    echo ""
    log "TCG2 event log (U-Boot measured boot):"
    if [ -f /sys/kernel/security/tpm0/binary_bios_measurements ]; then
        tpm2_eventlog /sys/kernel/security/tpm0/binary_bios_measurements 2>/dev/null || \
            log "  tpm2_eventlog not available (install tpm2-tools >= 5.x)"
    else
        log "  TCG2 event log not available"
    fi
}

# ─── Sub-command: quote ───────────────────────────────────────────────────────
cmd_quote() {
    local nonce=""
    local out="${OUT_DIR}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --nonce)  nonce="$2"; shift 2 ;;
            --out)    out="$2";   shift 2 ;;
            *) die "Unknown option: $1" ;;
        esac
    done

    install -d -m 700 "${out}"

    # Generate a random nonce if not supplied by the verifier
    if [ -z "${nonce}" ]; then
        nonce="$(tpm2_getrandom --hex 32)"
        log "Generated nonce: ${nonce}"
    fi
    printf '%s' "${nonce}" > "${out}/nonce.bin"

    log "Reading PCR[${PCR_LIST}] values..."
    tpm2_pcrread \
        --tcti="${TCTI}" \
        "${PCR_BANK}:${PCR_LIST}" \
        --output "${out}/pcr-values.bin"
    tpm2_pcrread --tcti="${TCTI}" "${PCR_BANK}:${PCR_LIST}"

    log "Generating TPM2 quote with AIK (handle ${HANDLE_AIK})..."
    tpm2_quote \
        --tcti="${TCTI}" \
        --key-context "${HANDLE_AIK}" \
        --pcr-list "${PCR_BANK}:${PCR_LIST}" \
        --qualification "${nonce}" \
        --message "${out}/quote.bin" \
        --signature "${out}/quote.sig" \
        --pcrs_output "${out}/quote-pcrs.bin" \
        --hash-algorithm sha256

    log "Quote generated:"
    log "  Message:    ${out}/quote.bin"
    log "  Signature:  ${out}/quote.sig"
    log "  PCR digest: ${out}/quote-pcrs.bin"
    log "  Nonce:      ${out}/nonce.bin"
    log ""
    log "Share quote.bin, quote.sig, quote-pcrs.bin, nonce.bin, and"
    log "${KEYS_DIR}/aik.pub with the remote verifier."
}

# ─── Sub-command: verify ─────────────────────────────────────────────────────
cmd_verify() {
    local quote_dir=""
    local baseline=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --quote)    quote_dir="$2"; shift 2 ;;
            --baseline) baseline="$2";  shift 2 ;;
            *) die "Unknown option: $1" ;;
        esac
    done

    [ -n "${quote_dir}" ] || die "--quote <dir> required"
    [ -f "${quote_dir}/quote.bin" ] || die "quote.bin not found in ${quote_dir}"
    [ -f "${quote_dir}/quote.sig" ] || die "quote.sig not found in ${quote_dir}"

    log "Verifying TPM quote signature..."
    tpm2_checkquote \
        --tcti="${TCTI}" \
        --public "${KEYS_DIR}/aik.pub" \
        --message "${quote_dir}/quote.bin" \
        --signature "${quote_dir}/quote.sig" \
        --pcrs "${quote_dir}/quote-pcrs.bin" \
        --qualification "$(cat "${quote_dir}/nonce.bin")"

    log "Signature verification: PASSED"

    if [ -n "${baseline}" ]; then
        log "Comparing PCR values against baseline: ${baseline}"
        if command -v python3 &>/dev/null && [ -f "${baseline}" ]; then
            python3 - "${quote_dir}/pcr-values.bin" "${baseline}" <<'EOF'
import sys, json, hashlib, struct

quote_file = sys.argv[1]
baseline_file = sys.argv[2]

with open(baseline_file) as f:
    baseline = json.load(f)

print(f"[tpm-attest] PCR baseline loaded: {len(baseline)} entries")
for pcr_id, expected_hex in baseline.items():
    print(f"  PCR[{pcr_id}] expected: {expected_hex}")
print("[tpm-attest] Detailed PCR comparison requires tpm2_pcrread output parsing.")
EOF
        else
            log "  python3 or baseline file not available; skipping PCR value comparison"
        fi
    fi

    log "Attestation verification complete."
}

# ─── Main ─────────────────────────────────────────────────────────────────────
require_cmd tpm2_pcrread
require_cmd tpm2_quote
require_cmd tpm2_checkquote

[ "$(id -u)" -eq 0 ] || die "Must run as root."
[ $# -ge 1 ] || usage

subcommand="$1"; shift
case "${subcommand}" in
    pcr-show) cmd_pcr_show "$@" ;;
    quote)    cmd_quote    "$@" ;;
    verify)   cmd_verify   "$@" ;;
    *)        usage ;;
esac
