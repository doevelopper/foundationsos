# ADR-0012: Production Hardening for v1.0.0

**Status:** Accepted  
**Date:** 2026-02-28  
**Deciders:** FoundationsOS maintainers

## Context

FoundationsOS v0.1.0 through v0.7.0 implemented the full security stack:
TF-A secure boot, OP-TEE TEE, TPM 2.0 measured boot, RAUC A/B OTA,
LUKS2 encrypted storage, IMA/EVM file integrity, and AppArmor MAC.

For the v1.0.0 production-ready release, we need defense-in-depth
hardening that closes gaps between individual component security and
whole-system production resilience.

## Decision

### 1. Kernel Command Line Hardening

Add the following parameters to the kernel command line for both boards:

| Parameter | Purpose |
|-----------|---------|
| `loglevel=1` | Suppress verbose kernel messages in production |
| `slub_debug=FZP` | Enable SLUB allocator poisoning, redzoning, sanity checks |
| `init_on_alloc=1` | Zero all heap allocations (prevents info leaks) |
| `init_on_free=1` | Zero freed memory (prevents use-after-free data leaks) |
| `page_alloc.shuffle=1` | Randomize page allocator freelists |
| `randomize_kstack_offset=on` | Randomize kernel stack offset per syscall |
| `slab_nomerge` | Prevent slab cache merging (hardens heap exploitation) |
| `lockdown=integrity` | Kernel lockdown — prevent userspace from modifying kernel |
| `panic=5` | Reboot after 5 seconds on kernel panic |

### 2. Sysctl Security Defaults

Deploy `/etc/sysctl.d/99-foundationsos-hardening.conf` on both boards:

- **Kernel info leaks:** `kptr_restrict=2`, `dmesg_restrict=1`, `perf_event_paranoid=3`
- **Exploitation hardening:** `kexec_load_disabled=1`, `unprivileged_bpf_disabled=1`, `yama.ptrace_scope=2`
- **Memory safety:** `mmap_min_addr=65536`, `mmap_rnd_bits=32`, `randomize_va_space=2`
- **Filesystem:** `protected_hardlinks=1`, `protected_symlinks=1`, `protected_fifos=2`, `suid_dumpable=0`
- **Network:** Disable redirects, source routing, enable SYN cookies, log martians, enable RFC3704 strict reverse path

### 3. Read-Only Rootfs with tmpfs Overlays

The rootfs is already mounted `ro` via kernel command line. For v1.0.0 we
add `tmpfiles.d` configuration to ensure volatile directories exist:
`/tmp`, `/var/tmp`, `/var/log`, `/var/log/journal`, `/var/lib/rauc`,
`/data`.

### 4. Global systemd Hardening

`/etc/systemd/system.conf.d/hardening.conf` sets:
- `DefaultLimitCORE=0` — no core dumps by default
- `DefaultLimitNOFILE=1024:65536` — reasonable FD limits
- CPU/memory/tasks accounting enabled
- Reduced service timeouts (30s vs 90s default)

### 5. SSH Production Hardening

`/etc/ssh/sshd_config.d/hardening.conf`:
- Root login: `prohibit-password` (key-only)
- Password authentication disabled entirely
- Modern cipher suite only (ChaCha20, AES-GCM)
- X11/TCP/agent forwarding disabled
- Session limits: 3 max, keepalive 5min

### 6. AppArmor Catchall Profile

A `foundationsos-default` profile in **complain mode** logs access to
sensitive resources by any process without a dedicated AppArmor profile.
This provides visibility into unexpected access patterns without breaking
system functionality. The profile can be upgraded to enforce mode after
a production audit period.

### 7. Security Audit Script

`scripts/security-audit.sh` — an on-target automated audit that checks:
kernel cmdline, sysctl values, mount options, SUID binaries, AppArmor
status, IMA/EVM state, TPM device, SSH config, systemd hardening,
and open network ports.

## Consequences

- **Positive:** Defense-in-depth hardening closes kernel, network, and
  userspace attack surfaces. Automated audit enables continuous compliance
  verification.
- **Positive:** All hardening is declarative (config files + kernel params),
  reproducible, and version-controlled.
- **Negative:** `lockdown=integrity` may interfere with runtime debugging;
  use `lockdown=none` for development builds.
- **Negative:** Read-only rootfs requires all stateful writes to go through
  designated paths (`/data`, `/var/log`, `/tmp`).

## References

- [Kernel Self Protection Project](https://kernsec.org/wiki/index.php/Kernel_Self_Protection_Project)
- [CIS Benchmark for Linux](https://www.cisecurity.org/benchmark/distribution_independent_linux)
- [ANSSI Linux Hardening Guide](https://www.ssi.gouv.fr/en/guide/recommendations-for-linux-configuration/)
- [systemd Sandboxing](https://www.freedesktop.org/software/systemd/man/systemd.exec.html)
