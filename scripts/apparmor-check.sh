#!/usr/bin/env bash
# apparmor-check.sh — Validate and display AppArmor profile status
#
# Usage:
#   scripts/apparmor-check.sh [--parse-only] [--dir <profile-dir>]
#
# Modes:
#   --parse-only  : Run apparmor_parser -p on all profiles (host/CI use);
#                   does NOT require a running AppArmor-enabled kernel.
#   (default)     : Query the running kernel for loaded profile status
#                   (target/runtime use).
#
# Dependencies: apparmor_parser (host), aa-status (target)

set -euo pipefail

PARSE_ONLY=false
PROFILE_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --parse-only) PARSE_ONLY=true; shift ;;
        --dir) PROFILE_DIR="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ─── Parse-only mode (CI / build host) ───────────────────────────────────────
if [[ "${PARSE_ONLY}" == "true" ]]; then
    if [[ -z "${PROFILE_DIR}" ]]; then
        echo "Usage: $0 --parse-only --dir <profile-dir>" >&2
        exit 1
    fi

    if ! command -v apparmor_parser &>/dev/null; then
        echo "[aa-check] ERROR: apparmor_parser not found." >&2
        echo "  Install: apt-get install apparmor" >&2
        exit 1
    fi

    ERRORS=0
    PARSED=0
    echo "[aa-check] Parsing profiles in: ${PROFILE_DIR}"
    while IFS= read -r -d '' f; do
        # Skip directories and the cache dir
        [[ -f "${f}" ]] || continue
        [[ "${f}" == *"/cache/"* ]] && continue
        [[ "${f}" == *"/local/"* ]] && continue

        if apparmor_parser --parse "${f}" 2>/dev/null; then
            echo "  OK: ${f}"
            PARSED=$((PARSED + 1))
        else
            echo "  FAIL: ${f}" >&2
            # Run again to show error
            apparmor_parser --parse "${f}" >&2 || true
            ERRORS=$((ERRORS + 1))
        fi
    done < <(find "${PROFILE_DIR}" -maxdepth 1 -type f -print0)

    echo "[aa-check] Parsed=${PARSED}  Errors=${ERRORS}"
    [[ ${ERRORS} -eq 0 ]]
    exit $?
fi

# ─── Runtime mode (target device) ────────────────────────────────────────────
if [[ ! -d /sys/kernel/security/apparmor ]]; then
    echo "[aa-check] ERROR: AppArmor securityfs not mounted." >&2
    echo "  Ensure apparmor=1 security=apparmor is in kernel cmdline." >&2
    exit 1
fi

echo "[aa-check] AppArmor status:"
echo "  Kernel: $(cat /sys/kernel/security/apparmor/features/domain/version 2>/dev/null || echo 'unknown')"
echo "  Mode:   $(cat /sys/kernel/security/apparmor/enforce 2>/dev/null || echo 'unknown')"

if command -v aa-status &>/dev/null; then
    aa-status
else
    echo "[aa-check] aa-status not found; reading directly from securityfs..."
    echo "  Loaded profiles:"
    cat /sys/kernel/security/apparmor/profiles 2>/dev/null || \
        ls /sys/kernel/security/apparmor/ | sed 's/^/    /'
fi

# Report profiles in complain mode (should be none in production)
COMPLAIN_COUNT=0
if command -v aa-status &>/dev/null; then
    COMPLAIN_COUNT=$(aa-status --json 2>/dev/null | \
        python3 -c "import sys,json; d=json.load(sys.stdin); \
        print(len(d.get('profiles',{}).get('complain',[])))" 2>/dev/null || echo 0)
fi

if [[ ${COMPLAIN_COUNT} -gt 0 ]]; then
    echo "[aa-check] WARNING: ${COMPLAIN_COUNT} profile(s) in complain mode." >&2
fi

echo "[aa-check] AppArmor check complete."
