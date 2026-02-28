# ADR-0011: AppArmor MAC Profiles for All System Services

| Field       | Value                      |
|-------------|----------------------------|
| Status      | Accepted                   |
| Date        | 2026-02-28                 |
| Milestone   | v0.7.0                     |
| Supersedes  | —                          |
| Authors     | FoundationsOS Contributors |

---

## Context

Prior milestones establish a measured boot chain, LUKS2 encrypted data, and
IMA/EVM file integrity enforcement. These controls protect the system against
**offline** tampering. The remaining attack surface is **runtime privilege
escalation**: a vulnerability in any privileged daemon (sshd, tpm2-abrmd,
rauc, tee-supplicant) could allow an attacker to:

- Access TPM key material (breaking LUKS sealing and EVM protection)
- Install an unsigned firmware or rootfs update via RAUC
- Exfiltrate secrets via the OP-TEE TEE supplicant interface
- Pivot laterally via SSH post-exploitation

AppArmor Mandatory Access Control (MAC) confines each service to the minimal
set of files, capabilities, and network access it actually requires. A
compromised process cannot escape its profile.

The kernel already has `apparmor=1 security=apparmor` in cmdline.txt and
`CONFIG_SECURITY_APPARMOR=y`, `CONFIG_DEFAULT_SECURITY_APPARMOR=y`, and
`CONFIG_LSM="lockdown,yama,loadpin,safesetid,integrity,apparmor,bpf"` in the
kernel fragment. This milestone writes and enforces the actual profiles.

---

## Decision

### Profile design principles

1. **Deny-by-default:** each profile starts with an implicit deny for all
   resources not explicitly allowed.
2. **Least privilege:** capabilities are granted individually; no `CAP_SYS_*`
   is granted unless strictly required.
3. **No wildcard network rules** for services that do not need network access
   (tee-supplicant, luks-init, evm-setup). `deny network inet` is explicit.
4. **Explicit sensitive path denials** (`/etc/shadow`, `/proc/kcore`,
   `/dev/tpm*` for non-TPM services, `/etc/tpm2/` for non-LUKS services) even
   though they are already implicitly denied — belt-and-braces approach.
5. **Enforce mode from day one** — `flags=(enforce)`. Complain mode is only
   used during profile development (not present in production image).
6. **D-Bus rules** use the strict `dbus` ABI with named service filters.

### Profiles

| Profile file | Confined binary | Key rules |
|---|---|---|
| `usr.sbin.tee-supplicant` | `/usr/sbin/tee-supplicant` | `/dev/tee*`, `/lib/optee_armtz/`, `/var/lib/tee/`; deny network |
| `usr.sbin.tpm2-abrmd` | `/usr/sbin/tpm2-abrmd` | `/dev/tpm*`, D-Bus `com.intel.tss2.Tabrmd`; deny `/etc/tpm2/` |
| `usr.bin.rauc` | `/usr/bin/rauc` | Block devices p1–p4, `/etc/rauc/`, `/data/rauc.db`, D-Bus `de.pengutronix.rauc` |
| `usr.bin.rauc-hawkbit-updater` | `/usr/bin/rauc-hawkbit-updater` | Outbound TCP (network stream), D-Bus to rauc; deny TPM |
| `usr.sbin.sshd` | `/usr/sbin/sshd` | TCP bind 22, pty, authorized_keys, child shell sub-profile; deny TPM |
| `lib.systemd.systemd-networkd` | `/lib/systemd/systemd-networkd` | `net_admin`, netlink, network config dirs; deny TPM |
| `lib.systemd.systemd-resolved` | `/lib/systemd/systemd-resolved` | DNS sockets, `org.freedesktop.resolve1` D-Bus; deny TPM |
| `usr.sbin.luks-init` | `/usr/sbin/luks-init.sh` | `/dev/mmcblk0p4`, `/etc/tpm2/luks-data.*`, `/run/luks/`, tpm2 tools; deny network |
| `usr.sbin.evm-setup` | `/usr/sbin/evm-setup.sh` | `/etc/tpm2/evm-hmac.*`, `/run/evm/`, `keyctl`, `/sys/kernel/security/evm`; deny network |

### Profile loader

`apparmor-load.service` runs at `Before=sysinit.target` (before any confined
process starts) and calls:

```bash
apparmor_parser --replace --write-cache /etc/apparmor.d
```

This atomically replaces all loaded profiles and writes a parse cache to
`/etc/apparmor.d/cache/` so that subsequent boots load the pre-compiled
binary cache rather than re-parsing text profiles (improves boot time).

### Service ordering

```
sysinit.target
  ↑ Before
apparmor-load.service     (loads all profiles)
  ↑ (profiles applied before processes start)
tpm2-abrmd.service        (confined by usr.sbin.tpm2-abrmd)
tee-supplicant.service    (confined by usr.sbin.tee-supplicant)
luks-data.service         (script confined by usr.sbin.luks-init)
evm-setup.service         (script confined by usr.sbin.evm-setup)
  ↑
multi-user.target
  ↑
rauc services             (confined by usr.bin.rauc*)
sshd                      (confined by usr.sbin.sshd)
systemd-networkd          (confined by lib.systemd.systemd-networkd)
systemd-resolved          (confined by lib.systemd.systemd-resolved)
```

---

## Alternatives Considered

| Alternative | Reason Rejected |
|---|---|
| SELinux instead of AppArmor | AppArmor already in LSM stack; SELinux requires labelling entire filesystem; higher complexity for embedded use case |
| Complain mode in production | Defeats the purpose; runtime violations are not acted upon; trivially bypassed by attacker |
| Single catch-all profile | Does not satisfy least-privilege; one escaped process could access all permitted resources |
| Systemd `CapabilityBoundingSet` only (no MAC) | Capability dropping is complementary but does not restrict file/network access; AppArmor is necessary |

---

## Security Considerations

1. **Profile updates with OTA:** AppArmor profiles are part of the read-only
   rootfs (installed via rootfs overlay). A RAUC OTA update that changes a
   service binary path requires a matching profile update in the same bundle.
   Profile files must be IMA-signed (covered by v0.6.0 ima-sign-rootfs.sh).

2. **Unconfined processes:** Processes not matching any profile are
   **unconfined** by default (AppArmor behaviour). The kernel audit subsystem
   will log any access by an unconfined process that would have been denied
   under a strict policy. Future milestone (v1.0.0) will add an
   `aa-enforce-unconfined` policy to catch stray processes.

3. **D-Bus mediation:** The `apparmor_parser` dbus rules require
   `CONFIG_SECURITY_APPARMOR_DBUS=y` (or the kernel `dbus-broker` LSM hook).
   Profiles degrade gracefully on kernels without D-Bus mediation.

4. **Profile for custom TAs:** OP-TEE Trusted Applications loaded via
   tee-supplicant run in S-EL1 (secure world) and are not visible to
   AppArmor (which is a Normal World LSM). TA isolation is provided by OP-TEE
   OS itself.

---

## References

- [AppArmor kernel documentation](https://www.kernel.org/doc/html/latest/admin-guide/LSM/apparmor.html)
- [AppArmor profile language](https://gitlab.com/apparmor/apparmor/-/wikis/QuickProfileLanguage)
- ADR-0006: OP-TEE Integration
- ADR-0007: TPM Measured Boot
- ADR-0009: LUKS2 TPM-sealed key
- ADR-0010: IMA/EVM full enforcement
