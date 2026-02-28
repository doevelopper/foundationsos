#!/usr/bin/env bash
# build-rauc-bundle.sh — Build a signed RAUC update bundle for FoundationsOS
#
# v0.4.0: Dual-board support (BOARD=raspberrypi5|raspberrypi3bp),
#         boot slot inclusion, SHA-256 in manifest, output in output/ root.
#
# Usage:
#   BOARD=raspberrypi5   ./scripts/build-rauc-bundle.sh
#   BOARD=raspberrypi3bp ./scripts/build-rauc-bundle.sh
#
# Environment variables:
#   BOARD                  — raspberrypi5 (default) or raspberrypi3bp
#   RAUC_KEY_FILE          — path to ECDSA signing private key
#   RAUC_CERT_FILE         — path to signing certificate
#   FOUNDATIONSOS_VERSION  — version string override (default: git describe)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"

BOARD="${BOARD:-raspberrypi5}"
case "${BOARD}" in
    raspberrypi5)   COMPATIBLE="foundationsos-rpi5" ;;
    raspberrypi3bp) COMPATIBLE="foundationsos-rpi3bp" ;;
    *)
        echo "ERROR: Unknown board '${BOARD}'. Use raspberrypi5 or raspberrypi3bp."
        exit 1 ;;
esac

OUTPUT_DIR="${ROOT_DIR}/output/${BOARD}"
IMAGES_DIR="${OUTPUT_DIR}/images"

VERSION="${FOUNDATIONSOS_VERSION:-$(git -C "${ROOT_DIR}" describe --tags --always 2>/dev/null || echo "dev")}"
BUNDLE_NAME="foundationsos-${BOARD}-${VERSION}.raucb"
BUNDLE_PATH="${ROOT_DIR}/output/${BUNDLE_NAME}"

RAUC_KEY_FILE="${RAUC_KEY_FILE:-${ROOT_DIR}/keys/rauc/signing.key.pem}"
RAUC_CERT_FILE="${RAUC_CERT_FILE:-${ROOT_DIR}/keys/rauc/signing.cert.pem}"
RAUC_KEYRING="${ROOT_DIR}/board/${BOARD}/rootfs_overlay/etc/rauc/ca.cert.pem"

# ─── Validation ──────────────────────────────────────────────────────────────
check_file() {
    if [[ ! -f "$1" ]]; then
        echo "ERROR: Required file not found: $1"
        echo "       $2"
        exit 1
    fi
}

check_file "${RAUC_KEY_FILE}"  "Set RAUC_KEY_FILE env var or run keys/rauc/gen-keys.sh"
check_file "${RAUC_CERT_FILE}" "Set RAUC_CERT_FILE env var or run keys/rauc/gen-keys.sh"
check_file "${RAUC_KEYRING}"   "CA certificate must be at ${RAUC_KEYRING}"

# Prefer ext4 (verity format), fall back to squashfs
if [[ -f "${IMAGES_DIR}/rootfs.ext4" ]]; then
    ROOTFS_SRC="${IMAGES_DIR}/rootfs.ext4"
    ROOTFS_FILENAME="rootfs.ext4"
elif [[ -f "${IMAGES_DIR}/rootfs.squashfs" ]]; then
    ROOTFS_SRC="${IMAGES_DIR}/rootfs.squashfs"
    ROOTFS_FILENAME="rootfs.squashfs"
else
    echo "ERROR: No rootfs image found in ${IMAGES_DIR}/"
    echo "       Run 'make build BOARD=${BOARD}' first."
    exit 1
fi

mkdir -p "$(dirname "${BUNDLE_PATH}")"

# ─── Assemble bundle staging area ────────────────────────────────────────────
STAGING=$(mktemp -d)
trap 'rm -rf "${STAGING}"' EXIT

echo "[rauc-bundle] Assembling bundle for BOARD=${BOARD} VERSION=${VERSION}..."
cp "${ROOTFS_SRC}" "${STAGING}/${ROOTFS_FILENAME}"
ROOTFS_SHA256=$(sha256sum "${STAGING}/${ROOTFS_FILENAME}" | awk '{print $1}')
echo "[rauc-bundle]   + rootfs: ${ROOTFS_FILENAME} (sha256=${ROOTFS_SHA256:0:16}...)"

# Optionally include boot slot
BOOT_SECTION=""
if [[ -f "${IMAGES_DIR}/boot.vfat" ]]; then
    cp "${IMAGES_DIR}/boot.vfat" "${STAGING}/boot.vfat"
    BOOT_SHA256=$(sha256sum "${STAGING}/boot.vfat" | awk '{print $1}')
    BOOT_SECTION="

[image.boot]
filename=boot.vfat
sha256=${BOOT_SHA256}"
    echo "[rauc-bundle]   + boot: boot.vfat (sha256=${BOOT_SHA256:0:16}...)"
fi

# ─── Write manifest ──────────────────────────────────────────────────────────
cat > "${STAGING}/manifest.raucm" <<EOF
[update]
compatible=${COMPATIBLE}
version=${VERSION}

[bundle]
format=verity

[image.rootfs]
filename=${ROOTFS_FILENAME}
sha256=${ROOTFS_SHA256}${BOOT_SECTION}
EOF

echo "[rauc-bundle] manifest.raucm:"
cat "${STAGING}/manifest.raucm"

# ─── Build signed bundle ─────────────────────────────────────────────────────
echo "[rauc-bundle] Signing with ${RAUC_CERT_FILE}..."
rauc bundle \
    --cert="${RAUC_CERT_FILE}" \
    --key="${RAUC_KEY_FILE}" \
    --keyring="${RAUC_KEYRING}" \
    "${STAGING}" \
    "${BUNDLE_PATH}"

sha256sum "${BUNDLE_PATH}" > "${BUNDLE_PATH}.sha256"

echo ""
echo "[rauc-bundle] ✅ Bundle ready: ${BUNDLE_PATH}"
echo "[rauc-bundle]    Compatible  : ${COMPATIBLE}"
echo "[rauc-bundle]    Version     : ${VERSION}"
echo "[rauc-bundle]    SHA256      : $(cat "${BUNDLE_PATH}.sha256")"
echo ""
echo "Install on device with:"
echo "  rauc install ${BUNDLE_PATH}"
