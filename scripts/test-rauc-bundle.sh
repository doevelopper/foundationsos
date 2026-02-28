#!/usr/bin/env bash
# test-rauc-bundle.sh — Validate RAUC configuration and bundles
#
# Usage:
#   ./scripts/test-rauc-bundle.sh --smoke-test            # validate configs (no bundle needed)
#   ./scripts/test-rauc-bundle.sh <bundle.raucb>          # validate a built bundle
#   ./scripts/test-rauc-bundle.sh <bundle.raucb> <ca.pem> # validate + verify signature
#
# Exit codes: 0 = all pass, 1 = one or more failures

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"

PASS=0
FAIL=0

ok()   { echo "  ✅  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  ❌  FAIL: $*"; FAIL=$((FAIL + 1)); }
info() { echo "  ℹ️   INFO: $*"; }
hdr()  { echo ""; echo "─── $* ───"; }

# ─── Smoke test (config + script validation; no images required) ─────────────
smoke_test() {
    echo ""
    echo "════════════════════════════════════════"
    echo "  FoundationsOS RAUC Smoke Test"
    echo "════════════════════════════════════════"

    for board in raspberrypi5 raspberrypi3bp; do
        hdr "${board}"

        # system.conf
        CONF="${ROOT_DIR}/board/${board}/rootfs_overlay/etc/rauc/system.conf"
        if [[ ! -f "${CONF}" ]]; then
            fail "system.conf missing: ${CONF}"; continue
        fi
        ok "system.conf present"
        grep -q "compatible=" "${CONF}" && ok "compatible = $(grep '^compatible=' "${CONF}" | cut -d= -f2)" || fail "missing compatible="
        grep -q "bootloader=uboot" "${CONF}" && ok "bootloader=uboot" || fail "bootloader not uboot"
        grep -q "bundle-formats=verity" "${CONF}" && ok "bundle-formats=verity" || fail "bundle-formats not verity"
        grep -q "statusfile=" "${CONF}" && ok "statusfile configured" || fail "statusfile missing"
        grep -q "use-bundle-signing-time=true" "${CONF}" && ok "use-bundle-signing-time=true" || fail "use-bundle-signing-time missing"
        grep -q "max-bundle-download-size=" "${CONF}" && ok "max-bundle-download-size set" || fail "max-bundle-download-size missing"

        # CA certificate
        CA="${ROOT_DIR}/board/${board}/rootfs_overlay/etc/rauc/ca.cert.pem"
        if [[ -f "${CA}" ]]; then
            ok "ca.cert.pem present"
            openssl x509 -in "${CA}" -noout 2>/dev/null && ok "ca.cert.pem is valid X.509" || fail "ca.cert.pem invalid"
        else
            info "ca.cert.pem not present (generate with keys/rauc/gen-keys.sh before deployment)"
        fi

        # hawkbit.conf
        HBC="${ROOT_DIR}/board/${board}/rootfs_overlay/etc/rauc/hawkbit.conf"
        if [[ -f "${HBC}" ]]; then
            ok "hawkbit.conf present"
            grep -q "hawkbit_server" "${HBC}" && ok "hawkbit_server configured" || fail "hawkbit_server missing"
            grep -q "ssl.*=.*true" "${HBC}" && ok "ssl=true" || fail "ssl not enabled"
            if grep -q "REPLACE_WITH" "${HBC}"; then
                info "hawkbit.conf has placeholder values (expected for dev builds)"
            fi
        else
            fail "hawkbit.conf missing"
        fi

        # Systemd services
        SVC_DIR="${ROOT_DIR}/board/${board}/rootfs_overlay/etc/systemd/system"
        for svc in rauc-mark-good rauc-hawkbit-updater tpm2-measured-boot tee-supplicant tpm2-abrmd; do
            if [[ -f "${SVC_DIR}/${svc}.service" ]]; then
                ok "${svc}.service present"
            else
                fail "${svc}.service missing for ${board}"
            fi
        done

        # Check rauc-mark-good runs after multi-user.target
        MG="${SVC_DIR}/rauc-mark-good.service"
        if [[ -f "${MG}" ]]; then
            grep -q "WantedBy=multi-user.target" "${MG}" && ok "rauc-mark-good WantedBy=multi-user.target" || fail "rauc-mark-good not wanted by multi-user.target"
        fi

        # Check rauc-hawkbit-updater runs after network-online.target
        HU="${SVC_DIR}/rauc-hawkbit-updater.service"
        if [[ -f "${HU}" ]]; then
            grep -q "network-online.target" "${HU}" && ok "rauc-hawkbit-updater After=network-online.target" || fail "rauc-hawkbit-updater missing network-online dependency"
            grep -q "NoNewPrivileges=yes" "${HU}" && ok "rauc-hawkbit-updater hardened (NoNewPrivileges)" || fail "rauc-hawkbit-updater not hardened"
        fi
    done

    # Scripts
    hdr "scripts"
    for script in build-rauc-bundle.sh test-rauc-bundle.sh; do
        F="${ROOT_DIR}/scripts/${script}"
        if [[ -f "${F}" ]]; then
            ok "${script} present"
            bash -n "${F}" 2>/dev/null && ok "${script} syntax OK" || fail "${script} has syntax errors"
        else
            fail "${script} missing"
        fi
    done

    F="${ROOT_DIR}/keys/rauc/gen-keys.sh"
    if [[ -f "${F}" ]]; then
        ok "gen-keys.sh present"
        bash -n "${F}" 2>/dev/null && ok "gen-keys.sh syntax OK" || fail "gen-keys.sh syntax errors"
    else
        fail "gen-keys.sh missing"
    fi

    # ADR
    hdr "documentation"
    for adr in 0002-ab-partition-rauc.md 0008-hawkbit-ota-connector.md; do
        F="${ROOT_DIR}/docs/adr/${adr}"
        [[ -f "${F}" ]] && ok "ADR ${adr} present" || fail "ADR ${adr} missing"
    done
}

# ─── Bundle validation ────────────────────────────────────────────────────────
validate_bundle() {
    local BUNDLE="$1"
    local KEYRING="${2:-}"

    hdr "Bundle: ${BUNDLE}"

    [[ -f "${BUNDLE}" ]] && ok "bundle file exists" || { fail "bundle not found: ${BUNDLE}"; return; }

    BUNDLE_SIZE=$(stat -c%s "${BUNDLE}" 2>/dev/null || stat -f%z "${BUNDLE}" 2>/dev/null || echo 0)
    ok "bundle size: $((BUNDLE_SIZE / 1024)) KiB"

    if ! command -v rauc &>/dev/null; then
        info "rauc not installed — skipping live inspection"
        return
    fi

    INSPECT_ARGS=()
    [[ -n "${KEYRING}" ]] && INSPECT_ARGS+=(--keyring "${KEYRING}")

    if rauc "${INSPECT_ARGS[@]}" info "${BUNDLE}" 2>&1; then
        ok "rauc info: bundle structure valid"
    else
        fail "rauc info failed"
        return
    fi

    COMPAT=$(rauc info "${BUNDLE}" 2>/dev/null | grep "Compatible:" | awk '{print $2}' || true)
    if [[ "${COMPAT}" == foundationsos-* ]]; then
        ok "compatible = ${COMPAT}"
    else
        fail "unexpected compatible: '${COMPAT}'"
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────
smoke_test

if [[ $# -gt 0 ]] && [[ "${1}" != "--smoke-test" ]]; then
    validate_bundle "${1}" "${2:-}"
fi

echo ""
echo "════════════════════════════════════════"
echo "  Results: ${PASS} passed, ${FAIL} failed"
echo "════════════════════════════════════════"
[[ ${FAIL} -eq 0 ]]
