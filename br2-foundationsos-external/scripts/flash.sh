#!/usr/bin/env bash
# flash.sh — Flash FoundationsOS SD card image to a block device
#
# Usage: ./scripts/flash.sh --device /dev/sdX [--image output/images/sdcard.img]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"

IMAGE="${ROOT_DIR}/output/images/sdcard.img"
DEVICE=""

# ─── Argument Parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --device|-d) DEVICE="$2"; shift 2 ;;
        --image|-i)  IMAGE="$2";  shift 2 ;;
        --help|-h)
            echo "Usage: $0 --device /dev/sdX [--image path/to/sdcard.img]"
            exit 0 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

# ─── Validation ───────────────────────────────────────────────────────────────
if [[ -z "${DEVICE}" ]]; then
    echo "ERROR: --device is required. Example: $0 --device /dev/sdb"
    exit 1
fi

if [[ ! -b "${DEVICE}" ]]; then
    echo "ERROR: ${DEVICE} is not a block device."
    exit 1
fi

if [[ ! -f "${IMAGE}" ]]; then
    echo "ERROR: Image file not found: ${IMAGE}"
    echo "       Run 'make build' first."
    exit 1
fi

# Safety: refuse to flash to a mounted device
if mount | grep -q "^${DEVICE}"; then
    echo "ERROR: ${DEVICE} appears to be mounted. Unmount it first."
    exit 1
fi

# ─── Confirmation ─────────────────────────────────────────────────────────────
IMAGE_SIZE=$(du -h "${IMAGE}" | cut -f1)
echo "⚠️  WARNING: This will ERASE ALL DATA on ${DEVICE}!"
echo "   Image : ${IMAGE} (${IMAGE_SIZE})"
echo "   Target: ${DEVICE}"
echo ""
read -r -p "Type 'yes' to confirm: " CONFIRM
if [[ "${CONFIRM}" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

# ─── Verify Checksum ──────────────────────────────────────────────────────────
CHECKSUM_FILE="${IMAGE}.sha256"
if [[ -f "${CHECKSUM_FILE}" ]]; then
    echo "[flash] Verifying image checksum..."
    sha256sum --check "${CHECKSUM_FILE}"
    echo "[flash] ✅ Checksum OK."
else
    echo "[flash] WARNING: No checksum file found. Proceeding without verification."
fi

# ─── Flash ────────────────────────────────────────────────────────────────────
echo "[flash] Flashing ${IMAGE} → ${DEVICE} ..."
sudo dd if="${IMAGE}" of="${DEVICE}" bs=4M status=progress conv=fsync
sync
echo "[flash] ✅ Flash complete. You can safely remove the SD card."
