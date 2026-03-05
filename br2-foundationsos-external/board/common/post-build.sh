#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# post-build.sh — Common post-build hook
# Invoked via: BR2_ROOTFS_POST_BUILD_SCRIPT
#
# Buildroot calls this script after all packages have been installed into
# TARGET_DIR but before any filesystem image is generated.
# Multiple scripts can be listed (space-separated); this is the common one
# that runs for every board variant.
#
# Calling convention (Buildroot 2026.02+):
#   $1       - TARGET_DIR (populated rootfs staging directory)
#   $2..n    - BR2_ROOTFS_POST_SCRIPT_ARGS   (shared with all hooks)
#              then BR2_ROOTFS_POST_BUILD_SCRIPT_ARGS (build-specific)
#
# Recognised named arguments (passed via BR2_ROOTFS_POST_SCRIPT_ARGS):
#   --board-gen=N   Board generation number embedded in /etc/issue
#                   e.g.  BR2_ROOTFS_POST_SCRIPT_ARGS="--board-gen=5"
#
# Standard Buildroot environment variables available:
#   HOST_DIR     - host sysroot        ($(O)/host)
#   STAGING_DIR  - staging sysroot
#   TARGET_DIR   - target rootfs       (also $1)
#   BUILD_DIR    - per-package builds  ($(O)/build)
#   BINARIES_DIR - final images        ($(O)/images)
#   BASE_DIR     - output base         ($(O))
#   BR2_EXTERNAL_FOUNDATIONSOS_PATH - path to this external tree

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
BOARD_COMMON_DIR="$(cd "$(dirname "$0")" && pwd)"

TARGET_DIR="${1:?TARGET_DIR argument is required}"
shift   # $@ now contains BR2_ROOTFS_POST_SCRIPT_ARGS + BR2_ROOTFS_POST_BUILD_SCRIPT_ARGS

log() { echo "[${SCRIPT_NAME}] $*"; }

# ---------------------------------------------------------------------------
# compute_version – derive a human-readable version string from the git repo.
#
# Resolution order:
#   1. Exact tag on HEAD           →  v1.2.3
#   2. Nearest tag + offset + hash →  v1.2.3-14-gabcdef7
#   3. Short commit hash (no tags) →  abcdef7
#   4. Unknown (no git repo)       →  0.0.0+unknown
#
# A "+dirty" suffix is appended when the working tree has uncommitted changes.
# ---------------------------------------------------------------------------
compute_version() {
    # Prefer the exported external-tree path; fall back to script location.
    local repo_dir="${BR2_EXTERNAL_FOUNDATIONSOS_PATH:-}"
    if [ -z "${repo_dir}" ]; then
        repo_dir="$(cd "${BOARD_COMMON_DIR}/../.." && pwd)"
    fi

    if ! git -C "${repo_dir}" rev-parse --git-dir >/dev/null 2>&1; then
        printf '0.0.0+unknown'
        return
    fi

    # Exact tag (clean release)?
    local exact_tag
    exact_tag=$(git -C "${repo_dir}" describe --exact-match --tags HEAD 2>/dev/null || true)
    if [ -n "${exact_tag}" ]; then
        printf '%s' "${exact_tag}"
        return
    fi

    # Nearest tag + distance + short hash ± dirty marker
    git -C "${repo_dir}" describe --tags --always --dirty="+dirty" 2>/dev/null \
        || git -C "${repo_dir}" rev-parse --short=8 HEAD
}

# ---------------------------------------------------------------------------
# Parse named arguments
# ---------------------------------------------------------------------------
BOARD_GEN=""
for arg in "$@"; do
    case "${arg}" in
        --board-gen=*) BOARD_GEN="${arg#--board-gen=}" ;;
    esac
done

# ---------------------------------------------------------------------------
# Dynamic version stamping
# ---------------------------------------------------------------------------
VERSION="$(compute_version)"
ISSUE_STRING="FoundationsOS ${VERSION} - Secured Embedded Linux${BOARD_GEN:+ ${BOARD_GEN}}"

log "--- Post-Build Hook: START ---"
log "TARGET_DIR   = ${TARGET_DIR}"
log "BINARIES_DIR = ${BINARIES_DIR:-<unset>}"
log "VERSION      = ${VERSION}"
log "BOARD_GEN    = ${BOARD_GEN:-<not set>}"
log "Extra args   = $*"

# /etc/issue  – shown on local ttys (includes escape codes for tty name / baud)
printf '%s \\n \\l\n' "${ISSUE_STRING}" > "${TARGET_DIR}/etc/issue"

# /etc/issue.net – shown over the network (no escape codes)
printf '%s\n' "${ISSUE_STRING}" > "${TARGET_DIR}/etc/issue.net"

# /etc/os-release – consumed by systemd and host tools; patch specific fields.
# Buildroot's system package writes this file; we update the version fields.
OS_RELEASE="${TARGET_DIR}/etc/os-release"
if [ -f "${OS_RELEASE}" ]; then
    # Replace existing fields in-place; append if absent.
    _set_os_field() {
        local key="$1" value="$2"
        if grep -q "^${key}=" "${OS_RELEASE}"; then
            sed -i "s|^${key}=.*|${key}=\"${value}\"|" "${OS_RELEASE}"
        else
            printf '%s="%s"\n' "${key}" "${value}" >> "${OS_RELEASE}"
        fi
    }
    _set_os_field "VERSION"      "${VERSION}"
    _set_os_field "VERSION_ID"   "${VERSION}"
    _set_os_field "PRETTY_NAME"  "${ISSUE_STRING}"
    _set_os_field "BUILD_ID"     "$(date -u +%Y%m%dT%H%M%SZ)"
fi

# ---------------------------------------------------------------------------
# TODO: Add further TARGET_DIR customisation steps here, for example:
#   - Remove development artifacts (headers, static libs, man pages)
#   - Harden filesystem permissions on sensitive files/directories
#   - Apply common overlays or skeletal configuration files
#   - Run policy/compliance checks against the staged rootfs
# ---------------------------------------------------------------------------

log "--- Post-Build Hook: DONE ---"
