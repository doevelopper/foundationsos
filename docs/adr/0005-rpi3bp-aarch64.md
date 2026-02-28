# ADR-0005: Support Raspberry Pi 3B+ in AArch64 (64-bit) Mode

## Status
Accepted

## Context
FoundationsOS was initially designed for the Raspberry Pi 5 (BCM2712, Cortex-A76). The Raspberry Pi 3 Model B+ (BCM2837, Cortex-A53) is a widely deployed platform that needs to be supported. The BCM2837 can operate in either 32-bit (ARMv7) or 64-bit (AArch64/ARMv8-A) mode.

## Decision
Support the RPi3B+ exclusively in **64-bit (AArch64) mode** by setting `arm_64bit=1` in `config.txt`.

## Rationale

| | 32-bit (ARMv7) | 64-bit AArch64 |
|--|---------------|----------------|
| OP-TEE support | Limited | Full (rpi3 platform) |
| ARM TF-A support | No AArch64 BL31 | `armstub=bl31.bin` |
| Pointer authentication (PAC) | No | Available (ARMv8.3+, not on A53, but code stays portable) |
| Consistent toolchain with RPi5 | No | Yes (single AArch64 cross-compiler) |
| Memory addressing | 32-bit physical | 36-bit LPAE physical |

Running in 64-bit mode enables a **single AArch64 toolchain** for both RPi3B+ and RPi5, simplifies the security stack (TF-A + OP-TEE both have first-class `rpi3` AArch64 ports), and keeps the code path consistent across boards.

## Consequences
- **Positive**: Single toolchain; full TF-A + OP-TEE support; consistent defconfig structure between boards.
- **Negative**: `arm_64bit=1` requires Raspberry Pi firmware ≥ 2016-10; older SD card images must be re-flashed. The Cortex-A53 does not support ARMv8.1 LSE atomics — the compiler flags must not include `-march=armv8.1-a`.
