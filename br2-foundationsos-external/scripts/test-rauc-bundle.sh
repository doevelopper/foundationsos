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
        if grep -q "compatible=" "${CONF}"; then ok "compatible = $(grep '^compatible=' "${CONF}" | cut -d= -f2)"; else fail "missing compatible="; fi
        if grep -q "bootloader=uboot" "${CONF}"; then ok "bootloader=uboot"; else fail "bootloader not uboot"; fi
        if grep -q "bundle-formats=verity" "${CONF}"; then ok "bundle-formats=verity"; else fail "bundle-formats not verity"; fi
        if grep -q "statusfile=" "${CONF}"; then ok "statusfile configured"; else fail "statusfile missing"; fi
        if grep -q "use-bundle-signing-time=true" "${CONF}"; then ok "use-bundle-signing-time=true"; else fail "use-bundle-signing-time missing"; fi
        if grep -q "max-bundle-download-size=" "${CONF}"; then ok "max-bundle-download-size set"; else fail "max-bundle-download-size missing"; fi

        # CA certificate
        CA="${ROOT_DIR}/board/${board}/rootfs_overlay/etc/rauc/ca.cert.pem"
        if [[ -f "${CA}" ]]; then
            ok "ca.cert.pem present"
            if openssl x509 -in "${CA}" -noout 2>/dev/null; then ok "ca.cert.pem is valid X.509"; else info "ca.cert.pem is placeholder (generate real cert before deployment)"; fi
        else
            info "ca.cert.pem not present (generate with keys/rauc/gen-keys.sh before deployment)"
        fi

        # hawkbit.conf
        HBC="${ROOT_DIR}/board/${board}/rootfs_overlay/etc/rauc/hawkbit.conf"
        if [[ -f "${HBC}" ]]; then
            ok "hawkbit.conf present"
            if grep -q "hawkbit_server" "${HBC}"; then ok "hawkbit_server configured"; else fail "hawkbit_server missing"; fi
            if grep -q "ssl.*=.*true" "${HBC}"; then ok "ssl=true"; else fail "ssl not enabled"; fi
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
            if grep -q "WantedBy=multi-user.target" "${MG}"; then ok "rauc-mark-good WantedBy=multi-user.target"; else fail "rauc-mark-good not wanted by multi-user.target"; fi
        fi

        # Check rauc-hawkbit-updater runs after network-online.target
        HU="${SVC_DIR}/rauc-hawkbit-updater.service"
        if [[ -f "${HU}" ]]; then
            if grep -q "network-online.target" "${HU}"; then ok "rauc-hawkbit-updater After=network-online.target"; else fail "rauc-hawkbit-updater missing network-online dependency"; fi
            if grep -q "NoNewPrivileges=yes" "${HU}"; then ok "rauc-hawkbit-updater hardened (NoNewPrivileges)"; else fail "rauc-hawkbit-updater not hardened"; fi
        fi
    done

    # Scripts
    hdr "scripts"
    for script in build-rauc-bundle.sh test-rauc-bundle.sh; do
        F="${ROOT_DIR}/scripts/${script}"
        if [[ -f "${F}" ]]; then
            ok "${script} present"
            if bash -n "${F}" 2>/dev/null; then ok "${script} syntax OK"; else fail "${script} has syntax errors"; fi
        else
            fail "${script} missing"
        fi
    done

    F="${ROOT_DIR}/keys/rauc/gen-keys.sh"
    if [[ -f "${F}" ]]; then
        ok "gen-keys.sh present"
        if bash -n "${F}" 2>/dev/null; then ok "gen-keys.sh syntax OK"; else fail "gen-keys.sh syntax errors"; fi
    else
        fail "gen-keys.sh missing"
    fi

    # ADR
    hdr "documentation"
    for adr in 0002-ab-partition-rauc.md 0008-hawkbit-ota-connector.md; do
        F="${ROOT_DIR}/docs/adr/${adr}"
        if [[ -f "${F}" ]]; then ok "ADR ${adr} present"; else fail "ADR ${adr} missing"; fi
    done
}

# ─── Bundle validation ────────────────────────────────────────────────────────
validate_bundle() {
    local BUNDLE="$1"
    local KEYRING="${2:-}"

    hdr "Bundle: ${BUNDLE}"

    if [[ -f "${BUNDLE}" ]]; then ok "bundle file exists"; else fail "bundle not found: ${BUNDLE}"; return; fi

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
