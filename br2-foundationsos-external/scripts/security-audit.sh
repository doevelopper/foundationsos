#!/bin/bash
# FoundationsOS — Production Security Audit Script
# Runs on-target to verify all hardening measures are active.
# Exit code: 0 = all checks pass, 1 = one or more failures.
#
# Usage: security-audit.sh [--verbose]

set -euo pipefail

VERBOSE="${1:-}"
PASS=0
FAIL=0
WARN=0

# --- Helpers ---
pass() { PASS=$((PASS + 1)); echo "  [PASS] $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  [FAIL] $1"; }
warn() { WARN=$((WARN + 1)); echo "  [WARN] $1"; }
section() { echo ""; echo "=== $1 ==="; }

# ============================
# 1. Kernel command line
# ============================
section "Kernel Command Line"

CMDLINE=$(cat /proc/cmdline)
for param in "ro" "quiet" "lockdown=integrity" "slub_debug=FZP" \
             "init_on_alloc=1" "init_on_free=1" "slab_nomerge" \
             "ima_policy=tcb" "ima_appraise=enforce" \
             "apparmor=1" "security=apparmor"; do
    if echo "${CMDLINE}" | grep -q "${param}"; then
        pass "Kernel param: ${param}"
    else
        fail "Kernel param missing: ${param}"
    fi
done

# ============================
# 2. Sysctl hardening
# ============================
section "Sysctl Hardening"

declare -A SYSCTL_CHECKS=(
    ["kernel.kptr_restrict"]="2"
    ["kernel.dmesg_restrict"]="1"
    ["kernel.perf_event_paranoid"]="3"
    ["kernel.yama.ptrace_scope"]="2"
    ["kernel.randomize_va_space"]="2"
    ["fs.protected_hardlinks"]="1"
    ["fs.protected_symlinks"]="1"
    ["fs.suid_dumpable"]="0"
    ["net.ipv4.conf.all.accept_redirects"]="0"
    ["net.ipv4.conf.all.send_redirects"]="0"
    ["net.ipv4.tcp_syncookies"]="1"
    ["net.ipv6.conf.all.accept_redirects"]="0"
)

for key in "${!SYSCTL_CHECKS[@]}"; do
    expected="${SYSCTL_CHECKS[$key]}"
    actual=$(sysctl -n "${key}" 2>/dev/null || echo "N/A")
    if [ "${actual}" = "${expected}" ]; then
        pass "sysctl ${key} = ${expected}"
    else
        fail "sysctl ${key} = ${actual} (expected ${expected})"
    fi
done

# ============================
# 3. Filesystem mounts
# ============================
section "Filesystem Mounts"

if mount | grep -q "on / type.*\bro\b"; then
    pass "Root filesystem is read-only"
else
    fail "Root filesystem is NOT read-only"
fi

if mount | grep -q "on /tmp type tmpfs"; then
    pass "/tmp is tmpfs"
else
    warn "/tmp is not a separate tmpfs"
fi

# ============================
# 4. SUID binaries
# ============================
section "SUID/SGID Binaries"

SUID_COUNT=$(find / -xdev -perm -4000 -type f 2>/dev/null | wc -l)
if [ "${SUID_COUNT}" -eq 0 ]; then
    pass "No SUID binaries found"
else
    warn "${SUID_COUNT} SUID binary(ies) found"
    if [ "${VERBOSE}" = "--verbose" ]; then
        find / -xdev -perm -4000 -type f 2>/dev/null
    fi
fi

# ============================
# 5. AppArmor status
# ============================
section "AppArmor"

if command -v aa-status &>/dev/null; then
    ENFORCED=$(aa-status --enforced 2>/dev/null || echo "0")
    COMPLAIN=$(aa-status --complaining 2>/dev/null || echo "0")
    if [ "${ENFORCED}" -gt 0 ]; then
        pass "AppArmor: ${ENFORCED} profile(s) in enforce mode"
    else
        fail "AppArmor: no enforced profiles"
    fi
    if [ "${COMPLAIN}" -gt 0 ]; then
        warn "AppArmor: ${COMPLAIN} profile(s) in complain mode"
    fi
elif [ -d /sys/kernel/security/apparmor ]; then
    pass "AppArmor kernel module loaded"
else
    fail "AppArmor not available"
fi

# ============================
# 6. IMA/EVM status
# ============================
section "IMA/EVM"

if [ -f /sys/kernel/security/ima/policy ]; then
    pass "IMA policy loaded"
else
    fail "IMA policy not loaded"
fi

if [ -f /sys/kernel/security/evm ]; then
    EVM_STATE=$(cat /sys/kernel/security/evm 2>/dev/null || echo "0")
    if [ "${EVM_STATE}" -ge 1 ]; then
        pass "EVM active (state=${EVM_STATE})"
    else
        warn "EVM not yet initialized (state=${EVM_STATE})"
    fi
else
    fail "EVM not available"
fi

# ============================
# 7. TPM 2.0 status
# ============================
section "TPM 2.0"

if [ -c /dev/tpm0 ] || [ -c /dev/tpmrm0 ]; then
    pass "TPM device present"
else
    fail "TPM device not found"
fi

if systemctl is-active tpm2-abrmd.service &>/dev/null; then
    pass "tpm2-abrmd service active"
else
    warn "tpm2-abrmd service not active"
fi

# ============================
# 8. SSH hardening
# ============================
section "SSH Hardening"

if command -v sshd &>/dev/null; then
    SSHD_CONFIG=$(sshd -T 2>/dev/null || true)
    if echo "${SSHD_CONFIG}" | grep -qi "permitrootlogin prohibit-password"; then
        pass "SSH: root password login disabled"
    else
        warn "SSH: root login policy not verified"
    fi
    if echo "${SSHD_CONFIG}" | grep -qi "passwordauthentication no"; then
        pass "SSH: password auth disabled"
    else
        warn "SSH: password authentication may be enabled"
    fi
    if echo "${SSHD_CONFIG}" | grep -qi "x11forwarding no"; then
        pass "SSH: X11 forwarding disabled"
    else
        warn "SSH: X11 forwarding may be enabled"
    fi
else
    warn "sshd not installed (expected on production)"
fi

# ============================
# 9. systemd service hardening
# ============================
section "systemd Service Hardening"

for svc in tpm2-abrmd tee-supplicant rauc sshd; do
    if systemctl is-active "${svc}.service" &>/dev/null; then
        # Check for NoNewPrivileges
        if systemctl show "${svc}.service" -p NoNewPrivileges 2>/dev/null | grep -q "yes"; then
            pass "${svc}: NoNewPrivileges=yes"
        else
            warn "${svc}: NoNewPrivileges not set"
        fi
    fi
done

# ============================
# 10. Open ports
# ============================
section "Network Ports"

if command -v ss &>/dev/null; then
    LISTEN_COUNT=$(ss -tlnH 2>/dev/null | wc -l)
    if [ "${LISTEN_COUNT}" -le 2 ]; then
        pass "Minimal open ports: ${LISTEN_COUNT} listening"
    else
        warn "${LISTEN_COUNT} TCP ports listening (review needed)"
        if [ "${VERBOSE}" = "--verbose" ]; then
            ss -tlnp 2>/dev/null
        fi
    fi
fi

# ============================
# Summary
# ============================
echo ""
echo "==============================="
echo "  AUDIT SUMMARY"
echo "  Pass: ${PASS}  Fail: ${FAIL}  Warn: ${WARN}"
echo "==============================="

if [ "${FAIL}" -gt 0 ]; then
    echo "RESULT: FAILED (${FAIL} failure(s))"
    exit 1
else
    echo "RESULT: PASSED"
    exit 0
fi
