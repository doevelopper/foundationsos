#!/usr/bin/env bash
# build-rauc-bundle.sh — Build a signed RAUC update bundle
#
# Prerequisites:
#   - Completed 'make build' (output/images/rootfs.squashfs present)
#   - RAUC_KEY_FILE pointing to the ECDSA private key (offline use only)
#   - RAUC_CERT_FILE pointing to the signing certificate

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
OUTPUT_DIR="${ROOT_DIR}/output"
IMAGES_DIR="${OUTPUT_DIR}/images"

# Version from git tag or fallback
VERSION="${FOUNDATIONSOS_VERSION:-$(git -C "${ROOT_DIR}" describe --tags --always 2>/dev/null || echo "dev")}"
BUNDLE_NAME="foundationsos-${VERSION}.raucb"
BUNDLE_PATH="${IMAGES_DIR}/${BUNDLE_NAME}"

RAUC_KEY_FILE="${RAUC_KEY_FILE:-${ROOT_DIR}/keys/rauc/signing.key.pem}"
RAUC_CERT_FILE="${RAUC_CERT_FILE:-${ROOT_DIR}/keys/rauc/signing.cert.pem}"
RAUC_KEYRING="${ROOT_DIR}/board/raspberrypi5/rootfs_overlay/etc/rauc/ca.cert.pem"

# ─── Validation ───────────────────────────────────────────────────────────────
if [[ ! -f "${RAUC_KEY_FILE}" ]]; then
    echo "ERROR: RAUC signing key not found: ${RAUC_KEY_FILE}"
    echo "       Set RAUC_KEY_FILE env var or generate keys with keys/rauc/gen-keys.sh"
    exit 1
fi

if [[ ! -f "${IMAGES_DIR}/rootfs.squashfs" ]]; then
    echo "ERROR: rootfs.squashfs not found. Run 'make build' first."
    exit 1
fi

# ─── Write manifest ───────────────────────────────────────────────────────────
MANIFEST_DIR=$(mktemp -d)
trap 'rm -rf "${MANIFEST_DIR}"' EXIT

cp "${IMAGES_DIR}/rootfs.squashfs" "${MANIFEST_DIR}/rootfs.img"

cat > "${MANIFEST_DIR}/manifest.raucm" <<EOF
[update]
compatible=foundationsos-rpi5
version=${VERSION}

[bundle]
format=verity

[image.rootfs]
filename=rootfs.img
EOF

# ─── Build bundle ─────────────────────────────────────────────────────────────
echo "[rauc-bundle] Building bundle ${BUNDLE_NAME}..."
rauc bundle \
    --cert="${RAUC_CERT_FILE}" \
    --key="${RAUC_KEY_FILE}" \
    --keyring="${RAUC_KEYRING}" \
    "${MANIFEST_DIR}" \
    "${BUNDLE_PATH}"

sha256sum "${BUNDLE_PATH}" > "${BUNDLE_PATH}.sha256"

echo "[rauc-bundle] ✅ Bundle ready: ${BUNDLE_PATH}"
echo "[rauc-bundle]    SHA256     : $(cat "${BUNDLE_PATH}.sha256")"
