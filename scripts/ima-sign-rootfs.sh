#!/usr/bin/env bash
# ima-sign-rootfs.sh — Sign all root-owned executables and shared libraries
#                      in TARGET_DIR with the IMA RSA-4096 signing key.
#
# Usage: scripts/ima-sign-rootfs.sh <TARGET_DIR> [--key <key.pem>] [--cert <cert.pem>]
#
# Called by board/raspberrypi{5,3bp}/post-build.sh during Buildroot's
# post-build phase (after rootfs assembly, before image creation).
#
# What it signs (security.ima xattr, ima-sig template):
#   - All ELF executables owned by root (mode u+x) under /bin /sbin /usr/bin
#     /usr/sbin /usr/lib /lib
#   - All shared libraries (.so*) under /lib /usr/lib
#   - Kernel modules (.ko) under /lib/modules
#
# Dependencies (host):
#   - evmctl  (from ima-evm-utils package, built as host-ima-evm-utils)
#   - openssl (host)
#   - file    (host, for ELF detection)
#
# Reference: https://sourceforge.net/p/linux-ima/wiki/Home/

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <TARGET_DIR> [--key <key.pem>] [--cert <cert.pem>]" >&2
    exit 1
fi

TARGET_DIR="$(realpath "$1")"; shift

KEY="${FOUNDATIONSOS_IMA_KEY:-keys/ima/ima-signing-key.pem}"
CERT="${FOUNDATIONSOS_IMA_CERT:-keys/ima/ima-signing-cert.pem}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --key)  KEY="$2";  shift 2 ;;
        --cert) CERT="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ ! -f "${KEY}" ]]; then
    echo "[ima-sign] ERROR: IMA signing key not found: ${KEY}" >&2
    echo "  Run scripts/generate-ima-keys.sh first." >&2
    exit 1
fi

if [[ ! -f "${CERT}" ]]; then
    echo "[ima-sign] ERROR: IMA signing cert not found: ${CERT}" >&2
    exit 1
fi

# Verify evmctl is available on the host
if ! command -v evmctl &>/dev/null; then
    echo "[ima-sign] ERROR: evmctl not found in PATH." >&2
    echo "  Install host-ima-evm-utils via Buildroot host packages." >&2
    exit 1
fi

echo "[ima-sign] Signing root filesystem: ${TARGET_DIR}"
echo "[ima-sign] Key:  ${KEY}"
echo "[ima-sign] Cert: ${CERT}"

SIGNED=0
SKIPPED=0
ERRORS=0

# Directories to scan
SCAN_DIRS=(
    "${TARGET_DIR}/bin"
    "${TARGET_DIR}/sbin"
    "${TARGET_DIR}/usr/bin"
    "${TARGET_DIR}/usr/sbin"
    "${TARGET_DIR}/lib"
    "${TARGET_DIR}/usr/lib"
    "${TARGET_DIR}/lib/modules"
)

sign_file() {
    local f="$1"
    # Sign with RSA-4096 SHA-256, append signature to security.ima xattr
    if evmctl ima_sign \
        --key "${KEY}" \
        --hashalgo sha256 \
        --imasig \
        "${f}" 2>/dev/null; then
        SIGNED=$((SIGNED + 1))
    else
        echo "[ima-sign] WARN: failed to sign: ${f}" >&2
        ERRORS=$((ERRORS + 1))
    fi
}

for dir in "${SCAN_DIRS[@]}"; do
    [[ -d "${dir}" ]] || continue

    # Sign ELF binaries (executables + shared objects)
    while IFS= read -r -d '' f; do
        # Check it's an ELF file
        if file "${f}" 2>/dev/null | grep -qE 'ELF.*(executable|shared object)'; then
            sign_file "${f}"
        else
            SKIPPED=$((SKIPPED + 1))
        fi
    done < <(find "${dir}" -type f \( -name "*.so*" -o -perm /0111 \) -print0 2>/dev/null)

    # Sign kernel modules
    while IFS= read -r -d '' f; do
        sign_file "${f}"
    done < <(find "${dir}" -type f -name "*.ko" -print0 2>/dev/null)
done

echo "[ima-sign] Done. Signed=${SIGNED}  Skipped=${SKIPPED}  Errors=${ERRORS}"

if [[ ${ERRORS} -gt 0 ]]; then
    echo "[ima-sign] WARNING: ${ERRORS} files could not be signed." >&2
    exit 1
fi
