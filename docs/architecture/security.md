# Security Architecture

## Threat Model

FoundationsOS is designed to resist the following threat classes on a deployed Raspberry Pi 5 device:

| Threat | Mitigation |
|--------|-----------|
| Unauthorized firmware replacement | ARM TF-A verified boot chain; TPM-sealed boot measurement |
| Physical tampering / evil-maid | TPM Platform Attestation; full-disk encryption (LUKS) |
| Malicious software update | RAUC cryptographic bundle signing; signature verification on-device |
| Privilege escalation | Kernel hardening; seccomp; AppArmor; capabilities reduction |
| Sensitive key extraction | Keys sealed in OP-TEE / TPM; never exposed in Normal World plaintext |
| Network-based attacks | nftables firewall; WolfSSL/mbedTLS; no unnecessary open ports |
| Supply-chain (image integrity) | IMA/EVM measures every file at runtime; SBOM published per release |

---

## Chain of Trust

```
[BCM2712 Hardware Root of Trust]
        │ OTP-fused public key hash
        ▼
[ARM TF-A BL1/BL2] — verifies BL31 & BL32 with RSA-4096
        │
        ▼
[OP-TEE BL32] — verifies each Trusted Application with its own signature
[U-Boot BL33] — verifies Linux FIT image; extends TPM PCR[8]
        │
        ▼
[Linux Kernel] — IMA measures every loaded binary into TPM PCR[10]
        │
        ▼
[systemd] — verifies service file integrity via IMA policy
```

---

## Key Management

### RAUC Signing Key
- **Algorithm**: ECDSA P-521
- **Key storage**: Offline HSM or air-gapped machine — **never in VCS**
- **Certificate rotation**: Annual or on compromise
- **On-device trust anchor**: `/etc/rauc/ca.cert.pem` (public cert only)

### OP-TEE Keys
- Stored in Secure World, sealed to platform configuration
- Access requires successful TEE authentication

### TPM Keys
- Platform Attestation Identity Key (AIK) generated at first boot
- Storage Root Key (SRK) seals application keys to PCR policy
- PCR[0–7]: TF-A / firmware measurements
- PCR[8]: U-Boot / bootloader measurement
- PCR[10]: Linux IMA aggregate

---

## Kernel Hardening Configuration

Selected kernel security options enabled in `linux-hardened.config`:

```
CONFIG_SECURITY=y
CONFIG_SECURITY_APPARMOR=y
CONFIG_IMA=y
CONFIG_IMA_APPRAISE=y
CONFIG_EVM=y
CONFIG_DM_CRYPT=y
CONFIG_BLK_DEV_DM=y
CONFIG_SECCOMP=y
CONFIG_SECCOMP_FILTER=y
CONFIG_HARDENED_USERCOPY=y
CONFIG_FORTIFY_SOURCE=y
CONFIG_STACKPROTECTOR_STRONG=y
CONFIG_RANDOMIZE_BASE=y   # KASLR
CONFIG_STRICT_KERNEL_RWX=y
CONFIG_DEBUG_RODATA=y
CONFIG_LOCKDOWN_LSM=y
```

---

## systemd Hardening

All critical service units include:

```ini
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=strict
ProtectHome=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
RestrictNamespaces=yes
CapabilityBoundingSet=<minimal set>
SystemCallFilter=@system-service
```
