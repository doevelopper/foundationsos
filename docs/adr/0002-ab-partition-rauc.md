# ADR-0002: Use RAUC with A/B Partitions for OTA Updates

## Status
Accepted

## Context
FoundationsOS is deployed on field devices that must be updated remotely without physical access. An update failure must never leave the device unbootable (bricked).

## Decision
Use **RAUC** with an **A/B (redundant) partition scheme** for atomic over-the-air updates.

## Rationale

| Criterion | RAUC A/B | Mender | Custom |
|-----------|----------|--------|--------|
| Atomic, rollback-safe updates | ✅ | ✅ | Depends |
| Cryptographic bundle signing | ✅ | ✅ | Extra work |
| Buildroot integration | Native package | Native package | N/A |
| U-Boot integration | First-class | First-class | N/A |
| Complexity | Low | Medium | High |

A/B slots guarantee that the currently running system is never modified during an update. U-Boot's boot counter / watchdog mechanism automatically rolls back to the previous good slot if the new slot fails to boot.

## Consequences
- **Positive**: Zero-downtime updates; automatic rollback on failure; cryptographically verified bundles prevent unauthorized firmware.
- **Negative**: SD card storage requirement doubles for the rootfs (two 512 MiB slots). On RPi3B+ with a 1 GiB RAM constraint this is acceptable since the concern is storage, not RAM.
