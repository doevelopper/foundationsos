# FoundationsOS Boot Chain

## Overview

FoundationsOS implements a measured, verified boot chain using ARM Trusted
Firmware-A (TF-A), OP-TEE, U-Boot, and the Linux kernel with TPM 2.0
measured boot support.

## Boot Sequence

```
┌─────────────┐
│  ROM / BL1   │  SoC boot ROM (immutable)
└──────┬──────┘
       │
┌──────▼──────┐
│   BL2 (TF-A) │  Trusted Firmware — first stage
└──────┬──────┘
       │
┌──────▼──────┐
│ BL31 (TF-A)  │  Secure Monitor (EL3)
│ BL32 (OP-TEE)│  Trusted OS (S-EL1)
└──────┬──────┘
       │
┌──────▼──────┐
│ BL33 (U-Boot)│  Bootloader (NS-EL2)
└──────┬──────┘
       │
┌──────▼──────┐
│  Linux Kernel │  Normal World OS (NS-EL1)
└──────┬──────┘
       │
┌──────▼──────┐
│   systemd     │  Init system + services
└─────────────┘
```

## TPM Measured Boot

Each stage extends TPM PCR registers with measurements of the next stage:

| PCR | Content |
|-----|---------|
| 0 | TF-A BL31 + U-Boot |
| 4 | Linux kernel image |
| 5 | Kernel command line |
| 7 | Device tree blob (DTB) |
| 8 | RAUC active boot slot |
| 10 | IMA runtime measurements |

## Security Properties

- **Chain of trust**: Each stage verifies the next before execution
- **Measured boot**: All boot components are measured into TPM PCRs
- **Sealed secrets**: LUKS keys and EVM keys are sealed to PCR policy
- **Rollback protection**: RAUC A/B updates with verified boot slots

## Board-Specific Details

### Raspberry Pi 5 (BCM2712)

- BL1: VideoCore firmware (`start4.elf`)
- Console: `ttyAMA10`
- DTB: `bcm2712-rpi-5-b.dtb`

### Raspberry Pi 3B+ (BCM2837)

- BL1: VideoCore firmware (`start.elf`)
- Console: `serial0` (mini UART via GPIO)
- DTB: `bcm2837-rpi-3-b-plus.dtb`

## Related

- [ADR-0006: TF-A + OP-TEE Boot Chain](../adr/0006-tfa-optee-boot-chain.md)
- [ADR-0007: TPM Measured Boot](../adr/0007-tpm-measured-boot.md)
