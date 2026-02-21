# Architecture Overview

## System Overview

FoundationsOS is a layered, security-hardened embedded Linux distribution for the Raspberry Pi 5 (BCM2712 / Cortex-A76). The design follows a **defense-in-depth** model with a hardware-rooted chain of trust, a Trusted Execution Environment, kernel-level hardening, and cryptographically verified over-the-air updates.

---

## Boot Chain

```
Power On (BCM2712 ROM)
        │
        ▼
  VideoCore IV Firmware (start4.elf / bootcode.bin)
  [Loads ARM Trusted Firmware from boot partition]
        │
        ▼
  ARM TF-A BL1 — First-stage bootloader in ROM/SRAM
        │  Verifies BL2 signature (RSA-4096)
        ▼
  ARM TF-A BL2 — Trusted Boot Firmware
        │  Initializes DRAM, verifies BL31 and BL32
        ▼
  ARM TF-A BL31 — EL3 Runtime Firmware (runs forever)
        │  Sets up Secure Monitor, SMC handlers
        ├──► BL32: OP-TEE OS (Secure World — EL1S)
        │          Trusted Applications, Crypto, Key Storage
        ▼
  U-Boot (Normal World BL33 — EL2)
        │  Verifies Linux kernel FIT image (verified boot)
        │  Extends TPM PCRs (measured boot)
        ▼
  Linux Kernel 6.6+ (Normal World — EL1)
        │  IMA measures every executed file
        │  dm-crypt unlocks encrypted rootfs
        ▼
  systemd (PID 1)
        │  Launches services with seccomp/AppArmor/cgroup isolation
        ▼
  User Applications / RAUC Update Agent
```

---

## Component Responsibilities

| Layer | Component | Responsibility |
|-------|-----------|----------------|
| Hardware | BCM2712 + TPM 2.0 | Platform root of trust, PCR measurements |
| EL3 | ARM TF-A BL31 | Secure monitor, SMC dispatcher, PSCI |
| Secure World (EL1S) | OP-TEE OS | TEE, Trusted Applications, GlobalPlatform APIs |
| Normal World Boot | U-Boot | Verified boot, TPM extend, kernel launch |
| Normal World OS | Linux 6.6+ | Process isolation, IMA/EVM, dm-crypt, namespaces |
| Init | systemd | Service lifecycle, cgroups v2, hardened units |
| Update | RAUC | Signed A/B atomic updates, rollback |
| Key Store | tpm2-tss / OP-TEE | Sealing, attestation, cryptographic operations |

---

## Partition Layout

| Partition | Label | Type | Size | Purpose |
|-----------|-------|------|------|---------|
| p1 | boot | FAT32 | 256 MiB | Firmware, TF-A, OP-TEE, U-Boot, DTBs |
| p2 | rootfs_a | ext4 | 512 MiB | Active root filesystem (RAUC slot A) |
| p3 | rootfs_b | ext4 | 512 MiB | Redundant root filesystem (RAUC slot B) |
| p4 | data | ext4 | 256 MiB | Persistent config, logs, application data |

---

## Further Reading

- [Security Model](security.md)
- [Boot Chain Detail](boot-chain.md)
- [Update Strategy](update-strategy.md)
- [ADR Index](../adr/README.md)
