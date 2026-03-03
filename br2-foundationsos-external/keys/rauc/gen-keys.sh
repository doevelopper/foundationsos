#!/usr/bin/env bash
# gen-keys.sh — Generate RAUC CA and bundle-signing key pair
# Run this ONCE on a trusted, air-gapped machine.
# Store private keys in an HSM or encrypted offline storage.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAYS_CA=7300    # 20 years
DAYS_SIGN=1825  # 5 years

echo "[gen-keys] Generating RAUC CA key pair (ECDSA P-521, ${DAYS_CA} days)..."
openssl req -x509 \
    -newkey ec -pkeyopt ec_paramgen_curve:P-521 \
    -keyout "${SCRIPT_DIR}/ca.key.pem" \
    -out    "${SCRIPT_DIR}/ca.cert.pem" \
    -days   "${DAYS_CA}" \
    -nodes \
    -subj "/CN=FoundationsOS RAUC CA/O=FoundationsOS/C=US"

echo "[gen-keys] Generating bundle signing key pair (ECDSA P-521, ${DAYS_SIGN} days)..."
openssl req -newkey ec -pkeyopt ec_paramgen_curve:P-521 \
    -keyout "${SCRIPT_DIR}/signing.key.pem" \
    -out    "${SCRIPT_DIR}/signing.csr" \
    -nodes \
    -subj "/CN=FoundationsOS RAUC Signing/O=FoundationsOS/C=US"

openssl x509 -req \
    -in   "${SCRIPT_DIR}/signing.csr" \
    -CA   "${SCRIPT_DIR}/ca.cert.pem" \
    -CAkey "${SCRIPT_DIR}/ca.key.pem" \
    -CAcreateserial \
    -out  "${SCRIPT_DIR}/signing.cert.pem" \
    -days "${DAYS_SIGN}"

rm -f "${SCRIPT_DIR}/signing.csr"

chmod 600 "${SCRIPT_DIR}/ca.key.pem" "${SCRIPT_DIR}/signing.key.pem"
chmod 644 "${SCRIPT_DIR}/ca.cert.pem" "${SCRIPT_DIR}/signing.cert.pem"

echo ""
echo "[gen-keys] ✅ Keys generated in ${SCRIPT_DIR}/"
echo ""
echo "  NEXT STEPS:"
echo "  1. Copy ca.cert.pem → board/raspberrypi5/rootfs_overlay/etc/rauc/ca.cert.pem"
echo "  2. Move ca.key.pem and signing.key.pem to OFFLINE / HSM storage"
echo "  3. Never commit private keys to the repository"
