# ADR-0001: Use Buildroot as the Build System

## Status
Accepted

## Context
FoundationsOS needs a reproducible build system to generate a minimal, security-hardened Linux image for an embedded target (Raspberry Pi 5). Candidate systems include Buildroot, Yocto/OpenEmbedded, and custom scripts.

## Decision
Use **Buildroot** as the primary build system.

## Rationale

| Criterion | Buildroot | Yocto |
|-----------|-----------|-------|
| Learning curve | Low | High |
| Build reproducibility | Good | Excellent |
| Footprint / simplicity | Minimal | Complex |
| Security package support | Good (TPM2, OP-TEE, RAUC) | Excellent |
| Community | Active | Very active |

Buildroot was chosen for its simplicity, speed, and sufficient security package coverage for our initial milestone. Migration to Yocto is planned if layer complexity demands it (see ADR-0005, TBD).

## Consequences
- **Positive**: Fast initial development, easy `defconfig` management, strong CI integration.
- **Negative**: Less fine-grained control over individual package versions than Yocto layers; binary reproducibility requires extra care.
