# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for FoundationsOS.

ADRs document significant design decisions, their context, and consequences.

## Index

| ADR | Title | Status |
|-----|-------|--------|
| [ADR-0001](0001-use-buildroot.md) | Use Buildroot as the build system | Accepted |
| [ADR-0002](0002-ab-partition-rauc.md) | Use RAUC with A/B partitions for OTA updates | Accepted |
| [ADR-0003](0003-optee-tpm2-key-storage.md) | Use OP-TEE + TPM2 for key storage and attestation | Accepted |
| [ADR-0004](0004-systemd-init.md) | Use systemd as the init system | Accepted |
| [ADR-0005](0005-rpi3bp-aarch64.md) | Support Raspberry Pi 3B+ in AArch64 (64-bit) mode | Accepted |

## Template

```markdown
# ADR-XXXX: Title

## Status
[Proposed | Accepted | Deprecated | Superseded by ADR-XXXX]

## Context
What is the issue motivating this decision?

## Decision
What was decided?

## Consequences
What are the positive and negative outcomes?
```
