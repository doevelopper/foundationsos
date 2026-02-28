#!/usr/bin/env bash
# generate-ima-keys.sh — Generate IMA signing key pair and EVM HMAC key
#
# Usage: scripts/generate-ima-keys.sh [--out-dir <dir>]
#
# Outputs (all created under --out-dir, default: keys/ima/):
#   ima-signing-key.pem   RSA-4096 private key (NEVER ship in production image)
#   ima-signing-cert.pem  X.509 certificate (embedded in kernel .ima_digsig)
#   ima-signing-cert.der  DER form (for kernel built-in keyring)
#   evm-hmac.key          32-byte random EVM HMAC key (TPM-seal before shipping)
#
# The private key must be kept secure (HSM or offline storage in production).
# Only the DER certificate is compiled into the kernel keyring; the private
# key is used only at build time by ima-sign-rootfs.sh.
#
# Dependencies: openssl (host), xxd (host)
#
# Reference:
#   https://sourceforge.net/p/linux-ima/wiki/Home/
#   Documentation/security/IMA-templates.rst

set -euo pipefail

OUT_DIR="keys/ima"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --out-dir) OUT_DIR="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

mkdir -p "${OUT_DIR}"
chmod 700 "${OUT_DIR}"

echo "[ima-keys] Generating RSA-4096 IMA signing key..."

# Generate private key
openssl genrsa -out "${OUT_DIR}/ima-signing-key.pem" 4096
chmod 600 "${OUT_DIR}/ima-signing-key.pem"

# Generate self-signed X.509 certificate (10-year validity)
openssl req -new -x509 \
    -key "${OUT_DIR}/ima-signing-key.pem" \
    -out "${OUT_DIR}/ima-signing-cert.pem" \
    -days 3650 \
    -subj "/CN=FoundationsOS IMA Signing Key/O=FoundationsOS/C=US" \
    -addext "basicConstraints=critical,CA:FALSE" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=codeSigning" \
    -sha256

chmod 644 "${OUT_DIR}/ima-signing-cert.pem"

# Convert to DER for embedding in kernel keyring
openssl x509 \
    -in  "${OUT_DIR}/ima-signing-cert.pem" \
    -out "${OUT_DIR}/ima-signing-cert.der" \
    -outform DER

chmod 644 "${OUT_DIR}/ima-signing-cert.der"

echo "[ima-keys] Generating 32-byte EVM HMAC key..."
# EVM HMAC key: 32 bytes of CSPRNG output stored as raw binary.
# At factory provisioning this key is:
#   1. Loaded into the kernel EVM keyring: keyctl add user evm-key $key @s
#   2. Sealed to the TPM under SRK (see scripts/evm-setup.sh)
# The file here is for BUILD-TIME use only (post-build xattr signing).
dd if=/dev/urandom bs=32 count=1 of="${OUT_DIR}/evm-hmac.key" 2>/dev/null
chmod 600 "${OUT_DIR}/evm-hmac.key"

echo ""
echo "[ima-keys] Keys generated in ${OUT_DIR}/"
echo "  Private key : ${OUT_DIR}/ima-signing-key.pem  (KEEP SECRET)"
echo "  Certificate : ${OUT_DIR}/ima-signing-cert.pem"
echo "  DER cert    : ${OUT_DIR}/ima-signing-cert.der  (embed in kernel)"
echo "  EVM HMAC key: ${OUT_DIR}/evm-hmac.key           (seal to TPM)"
echo ""
echo "Next steps:"
echo "  1. Add CONFIG_SYSTEM_EXTRA_CERTIFICATE to kernel; point to the DER cert."
echo "  2. Run scripts/ima-sign-rootfs.sh <TARGET_DIR> to sign all binaries."
echo "  3. Seal ${OUT_DIR}/evm-hmac.key to TPM (see scripts/evm-setup.sh)."
echo "  4. NEVER commit ima-signing-key.pem or evm-hmac.key to version control."
