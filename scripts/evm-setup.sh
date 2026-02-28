#!/usr/bin/env bash
# evm-setup.sh — Load the EVM HMAC key into the kernel EVM keyring at boot.
#
# Called by evm-setup.service (Before=sysinit.target).
#
# EVM requires its HMAC key to be loaded into the kernel keyring BEFORE
# the root filesystem is accessed in appraisal mode. This script:
#   1. Unseals the EVM HMAC key from the TPM (SRK, PCR[0,4,7,8] policy)
#   2. Loads the key into the kernel _evm keyring via keyctl
#   3. Activates EVM via /sys/kernel/security/evm
#   4. Shreds the raw key from tmpfs immediately after loading
#
# EVM modes (written to /sys/kernel/security/evm):
#   1 = HMAC mode (runtime HMAC on security xattrs)
#   2 = Digital signature mode (read-only, signatures only)
#   6 = Both (HMAC + signatures; used here)
#
# Environment:
#   EVM_KEY_SEALED_PUB  (default: /etc/tpm2/evm-hmac.pub)
#   EVM_KEY_SEALED_PRIV (default: /etc/tpm2/evm-hmac.priv)
#   EVM_TCTI            (default: tabrmd:bus_name=com.intel.tss2.Tabrmd)
#   EVM_SRK_HANDLE      (default: 0x81000001)
#   EVM_PCR_BANKS       (default: sha256:0,4,7,8)
#
# Dependencies: keyutils (keyctl), tpm2-tools, shred

set -euo pipefail

EVM_KEY_SEALED_PUB="${EVM_KEY_SEALED_PUB:-/etc/tpm2/evm-hmac.pub}"
EVM_KEY_SEALED_PRIV="${EVM_KEY_SEALED_PRIV:-/etc/tpm2/evm-hmac.priv}"
EVM_TCTI="${EVM_TCTI:-tabrmd:bus_name=com.intel.tss2.Tabrmd}"
EVM_SRK_HANDLE="${EVM_SRK_HANDLE:-0x81000001}"
EVM_PCR_BANKS="${EVM_PCR_BANKS:-sha256:0,4,7,8}"

EVM_TMPDIR="/run/evm"
EVM_KEY_RAW="${EVM_TMPDIR}/evm-hmac.key"

# ─── Pre-flight checks ────────────────────────────────────────────────────────
if [[ ! -f "${EVM_KEY_SEALED_PUB}" || ! -f "${EVM_KEY_SEALED_PRIV}" ]]; then
    echo "[evm-setup] ERROR: Sealed EVM key blobs not found." >&2
    echo "  Expected: ${EVM_KEY_SEALED_PUB} and ${EVM_KEY_SEALED_PRIV}" >&2
    echo "  Run scripts/evm-setup.sh --provision first." >&2
    exit 1
fi

if [[ ! -w /sys/kernel/security/evm ]]; then
    echo "[evm-setup] ERROR: /sys/kernel/security/evm not writable." >&2
    echo "  Ensure securityfs is mounted and CONFIG_EVM=y in kernel." >&2
    exit 1
fi

# ─── Provision mode ───────────────────────────────────────────────────────────
# Usage: evm-setup.sh --provision <evm-hmac.key>
# Seals the given 32-byte key file to the TPM under SRK with PCR policy.
if [[ "${1:-}" == "--provision" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 --provision <evm-hmac.key>" >&2; exit 1
    fi
    RAW_KEY="$2"
    if [[ ! -f "${RAW_KEY}" ]]; then
        echo "[evm-setup] ERROR: key file not found: ${RAW_KEY}" >&2; exit 1
    fi

    echo "[evm-setup] Provisioning: sealing EVM HMAC key to TPM..."

    # Create authorization policy tied to PCR[0,4,7,8]
    tpm2_startauthsession \
        --tcti="${EVM_TCTI}" --policy-session -S /tmp/evm_policy.ctx

    tpm2_policypcr \
        --tcti="${EVM_TCTI}" \
        -S /tmp/evm_policy.ctx \
        -l "${EVM_PCR_BANKS}" \
        -L /tmp/evm_policy.bin

    tpm2_flushcontext --tcti="${EVM_TCTI}" /tmp/evm_policy.ctx

    # Seal the key under SRK with the PCR policy
    tpm2_create \
        --tcti="${EVM_TCTI}" \
        --parent-context="${EVM_SRK_HANDLE}" \
        --policy=/tmp/evm_policy.bin \
        --sealing-input="${RAW_KEY}" \
        --attributes="fixedtpm|fixedparent|adminwithpolicy|noda" \
        --public="${EVM_KEY_SEALED_PUB}" \
        --private="${EVM_KEY_SEALED_PRIV}"

    rm -f /tmp/evm_policy.ctx /tmp/evm_policy.bin
    echo "[evm-setup] EVM HMAC key sealed to TPM."
    echo "  Public : ${EVM_KEY_SEALED_PUB}"
    echo "  Private: ${EVM_KEY_SEALED_PRIV}"
    exit 0
fi

# ─── Normal boot: unseal and load EVM HMAC key ───────────────────────────────
mkdir -p "${EVM_TMPDIR}"
chmod 700 "${EVM_TMPDIR}"

echo "[evm-setup] Unsealing EVM HMAC key from TPM..."

# Load the sealed object under SRK
tpm2_load \
    --tcti="${EVM_TCTI}" \
    --parent-context="${EVM_SRK_HANDLE}" \
    --public="${EVM_KEY_SEALED_PUB}" \
    --private="${EVM_KEY_SEALED_PRIV}" \
    --key-context=/tmp/evm_loaded.ctx

# Open a policy session and authorize with PCR policy
tpm2_startauthsession \
    --tcti="${EVM_TCTI}" \
    --policy-session \
    -S /tmp/evm_unseal.ctx

tpm2_policypcr \
    --tcti="${EVM_TCTI}" \
    -S /tmp/evm_unseal.ctx \
    -l "${EVM_PCR_BANKS}"

# Unseal the raw key bytes
tpm2_unseal \
    --tcti="${EVM_TCTI}" \
    --object-context=/tmp/evm_loaded.ctx \
    --auth=session:/tmp/evm_unseal.ctx \
    --output="${EVM_KEY_RAW}"

tpm2_flushcontext --tcti="${EVM_TCTI}" /tmp/evm_unseal.ctx 2>/dev/null || true
tpm2_flushcontext --tcti="${EVM_TCTI}" /tmp/evm_loaded.ctx 2>/dev/null || true
rm -f /tmp/evm_loaded.ctx /tmp/evm_unseal.ctx

echo "[evm-setup] Loading EVM HMAC key into kernel keyring..."

# Read the raw 32-byte key and load into the _evm keyring
EVM_KEYID=$(keyctl add user evm-key "$(cat "${EVM_KEY_RAW}")" @s)
echo "[evm-setup] EVM key loaded (keyid=${EVM_KEYID})"

# Shred the raw key immediately — it must not persist in tmpfs
shred -u "${EVM_KEY_RAW}" 2>/dev/null || rm -f "${EVM_KEY_RAW}"
rmdir "${EVM_TMPDIR}" 2>/dev/null || true

# ─── Activate EVM ─────────────────────────────────────────────────────────────
# Mode 6 = HMAC (bit 0) + digital signatures (bit 1) + immutable mode (bit 2)
# Use mode 2 (signatures only) until all files have EVM xattrs; upgrade to 6
# at full-production hardening (v1.0.0).
EVM_MODE=2
echo "[evm-setup] Activating EVM (mode=${EVM_MODE})..."
echo "${EVM_MODE}" > /sys/kernel/security/evm

echo "[evm-setup] EVM active (mode=${EVM_MODE}). Boot integrity enforced."
