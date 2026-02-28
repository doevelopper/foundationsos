# ADR-0003: Use OP-TEE + TPM2 for Key Storage and Attestation

## Status
Accepted

## Context
FoundationsOS handles sensitive keys (RAUC signing trust anchor, disk encryption keys, application secrets). These must be protected from extraction even if the Normal World Linux OS is compromised.

## Decision
Use **OP-TEE** (Secure World TEE) for runtime key operations and **TPM 2.0** for platform attestation and sealed key storage.

## Rationale

- **OP-TEE**: Provides an isolated GlobalPlatform TEE on both RPi3 and RPi5. Keys used in Trusted Applications never appear in Normal World plaintext. Supports sealing to a TEE identity.
- **TPM 2.0** (SPI module, e.g. Infineon SLB9670): Hardware security chip that extends PCR registers at each boot stage, enabling remote attestation. Storage keys can be sealed to a PCR policy, meaning decryption only succeeds when the platform boots in a known-good state.

The two complement each other: TPM provides hardware attestation and measured boot; OP-TEE provides a flexible runtime TEE for application-level crypto.

## Consequences
- **Positive**: Private keys are never exposed to the Normal World; measured boot detects tampering; remote attestation enables zero-trust device management.
- **Negative**: Requires an external SPI TPM module (not built into RPi3/RPi5 SoC); adds build complexity (tpm2-tss, tpm2-abrmd); OP-TEE platform ports for RPi3/RPi5 have limited upstream maintenance.
