# FoundationsOS

<div align="center">

[![CI](https://github.com/doevelopper/foundationsos/actions/workflows/ci.yml/badge.svg)](https://github.com/doevelopper/foundationsos/actions/workflows/ci.yml)
[![Release](https://github.com/doevelopper/foundationsos/actions/workflows/release.yml/badge.svg)](https://github.com/doevelopper/foundationsos/actions/workflows/release.yml)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![REUSE compliant](https://api.reuse.software/badge/github.com/doevelopper/foundationsos)](https://api.reuse.software/info/github.com/doevelopper/foundationsos)

**A security-hardened embedded Linux OS for Raspberry Pi 5 & 3B+**  
*Built on Buildroot · Secured by TPM2 · Protected by OP-TEE & ARM TF-A · Updated via RAUC*

</div>

---

## Overview

**FoundationsOS** is a production-grade, security-first embedded Linux distribution targeting **Raspberry Pi 5** (BCM2712) and **Raspberry Pi 3 Model B+** (BCM2837, AArch64 64-bit mode). It is built with [Buildroot](https://buildroot.org/) and integrates a full chain of trust from hardware-backed root of trust to over-the-air update delivery.

## Supported Platforms

| Board | SoC | CPU | `BOARD=` |
|-------|-----|-----|----------|
| Raspberry Pi 5 | BCM2712 | 4× Cortex-A76 @ 2.4 GHz | `raspberrypi5` (default) |
| Raspberry Pi 3 Model B+ | BCM2837 | 4× Cortex-A53 @ 1.4 GHz (AArch64) | `raspberrypi3bp` |

### Key Features

| Feature | Component | Purpose |
|---------|-----------|---------|
| **Secure Boot** | ARM Trusted Firmware-A (TF-A) | Hardware-enforced boot chain of trust |
| **TEE** | OP-TEE OS | Trusted Execution Environment (GlobalPlatform TEE) |
| **Hardware Security** | TPM 2.0 (via SPI) | Platform attestation, key storage, measured boot |
| **Atomic OTA Updates** | RAUC | Fail-safe A/B partition updates |
| **Init System** | systemd | Service management, hardened units, cgroups v2 |
| **Mandatory Access Control** | SELinux / AppArmor | Kernel-enforced access policies |
| **Encrypted Storage** | dm-crypt / LUKS | Full filesystem encryption |
| **Secure Communications** | WolfSSL / mbedTLS | FIPS-validated crypto libraries |
| **IMA/EVM** | Linux IMA subsystem | Integrity measurement and appraisal |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        FoundationsOS Stack                       │
├─────────────────────────────────────────────────────────────────┤
│  Applications / Services  (Normal World - Linux userspace)       │
│  ┌──────────┐ ┌────────┐ ┌──────────┐ ┌──────────────────────┐ │
│  │  RAUC    │ │systemd │ │ tpm2-tss │ │  Custom Applications │ │
│  └──────────┘ └────────┘ └──────────┘ └──────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│  Linux Kernel 6.6+ (RPi5/BCM2712) + IMA/EVM + dm-crypt          │
├───────────────────────────┬─────────────────────────────────────┤
│  Normal World             │  Secure World (OP-TEE)               │
│  ARM Cortex-A76           │  OP-TEE OS + TAs                     │
├───────────────────────────┴─────────────────────────────────────┤
│  ARM Trusted Firmware-A (BL1 / BL2 / BL31 / BL32)               │
├─────────────────────────────────────────────────────────────────┤
│  Hardware: BCM2712 · TPM 2.0 (SPI) · eMMC/NVMe Storage          │
└─────────────────────────────────────────────────────────────────┘
```

See [docs/architecture/overview.md](docs/architecture/overview.md) for the full architecture documentation.

---

## Quick Start

### Prerequisites

```bash
# Ubuntu 22.04 / Debian 12
sudo apt-get update && sudo apt-get install -y \
    build-essential git wget cpio unzip rsync bc \
    python3 python3-pip python3-setuptools \
    libssl-dev libncurses-dev file \
    device-tree-compiler bison flex

# Clone the repository
git clone https://github.com/doevelopper/foundationsos.git
cd foundationsos

# Bootstrap the build environment
make setup
```

### Building

```bash
# Configure and build for Raspberry Pi 5 (default)
make configure
make build

# Configure and build for Raspberry Pi 3 Model B+ (AArch64)
make configure BOARD=raspberrypi3bp
make build     BOARD=raspberrypi3bp

# Output images are in output/<board>/images/
```

### Flashing

```bash
# Flash RPi5 image
make flash DEVICE=/dev/sdX

# Flash RPi3B+ image
make flash BOARD=raspberrypi3bp DEVICE=/dev/sdX

# Or use the helper script directly
./scripts/flash.sh --device /dev/sdX --image output/raspberrypi3bp/images/sdcard.img
```

### OTA Update

```bash
# Build an update bundle
make rauc-bundle

# Install the bundle on the device
rauc install /path/to/foundationsos-<version>.raucb
```

---

## Repository Structure

```
foundationsos/
├── .github/                    # GitHub Actions, issue templates, PR templates
│   ├── workflows/              # CI/CD pipelines
│   └── ISSUE_TEMPLATE/         # Bug report & feature request templates
├── board/
│   ├── raspberrypi5/           # Raspberry Pi 5 board files
│   │   ├── rootfs_overlay/     # Files overlaid onto the root filesystem
│   │   ├── patches/            # Board-specific patches
│   │   ├── post-build.sh
│   │   ├── post-image.sh
│   │   └── genimage.cfg        # Disk image layout (256 MiB boot, A/B rootfs)
│   └── raspberrypi3bp/         # Raspberry Pi 3B+ board files (AArch64)
│       ├── rootfs_overlay/
│       │   └── boot/
│       │       ├── config.txt  # arm_64bit=1, armstub=bl31.bin, tpm-slb9670
│       │       └── cmdline.txt
│       ├── patches/
│       ├── post-build.sh
│       ├── post-image.sh
│       └── genimage.cfg        # Disk image layout (128 MiB boot, A/B rootfs)
├── configs/
│   ├── raspberrypi5_defconfig  # Buildroot defconfig — RPi5 (Cortex-A76)
│   └── raspberrypi3bp_defconfig # Buildroot defconfig — RPi3B+ (Cortex-A53, AArch64)
├── docs/                       # Project documentation
│   ├── architecture/           # Architecture diagrams and guides
│   ├── adr/                    # Architecture Decision Records (ADR-0001–0005)
│   └── *.md
├── external/
│   └── package/                # External Buildroot packages
├── keys/                       # Key generation scripts (NO private keys in VCS)
│   ├── rauc/
│   └── optee/
├── scripts/                    # Build & utility scripts
│   ├── setup-env.sh
│   ├── build.sh
│   └── flash.sh
├── Makefile                    # Board-aware top-level targets (BOARD=...)
├── CHANGELOG.md
├── CONTRIBUTING.md
└── LICENSE
```

---

## Security Model

FoundationsOS implements a **defense-in-depth** security model:

1. **Boot Integrity** — ARM TF-A enforces a verified boot chain. Each stage verifies the next using RSA-4096 / ECDSA-P521 signatures before handing off control.
2. **Platform Attestation** — TPM 2.0 extends PCRs at each boot stage. Remote attestation lets management servers verify platform integrity.
3. **Trusted Execution** — OP-TEE provides an isolated Secure World for cryptographic operations, key management, and sensitive workloads via Trusted Applications.
4. **Kernel Hardening** — IMA/EVM measures every executed file; dm-crypt encrypts storage; the kernel is built with a hardened configuration.
5. **Runtime Isolation** — systemd units use `CapabilityBoundingSet`, `PrivateTmp`, `NoNewPrivileges`, and seccomp filters. AppArmor profiles enforce per-service MAC.
6. **Update Integrity** — RAUC bundles are signed with an offline key. The device verifies the signature before applying any update. A/B slots ensure rollback safety.

See [docs/architecture/security.md](docs/architecture/security.md) for the complete threat model.

---

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

- **Bug reports** → [GitHub Issues](https://github.com/doevelopper/foundationsos/issues) (use the Bug Report template)
- **Feature requests** → [GitHub Issues](https://github.com/doevelopper/foundationsos/issues) (use the Feature Request template)
- **Security vulnerabilities** → Please use [GitHub Security Advisories](https://github.com/doevelopper/foundationsos/security/advisories/new) — **do not** file a public issue.

---

## Roadmap

- [x] v0.1.0 — Baseline Buildroot image booting on RPi5 ✅
- [x] v0.1.1 — Baseline Buildroot image booting on RPi3B+ (AArch64) ✅
- [x] v0.2.0 — ARM TF-A + OP-TEE integration (RPi5 & RPi3B+) ✅
- [x] v0.3.0 — TPM 2.0 measured boot & attestation ✅
- [x] v0.4.0 — RAUC A/B OTA updates (bundle signing, hawkBit connector) ✅
- [x] v0.5.0 — Full disk encryption (dm-crypt/LUKS2, TPM-sealed key)
- [x] v0.6.0 — IMA/EVM file integrity enforcement (RSA-4096 signed hashes + EVM HMAC)
- [x] v0.7.0 — AppArmor MAC profiles in enforce mode (9 services, both boards)
- [ ] v1.0.0 — Production-ready hardened image (both boards)

---

## License

Copyright 2024 FoundationsOS Contributors

Licensed under the [Apache License, Version 2.0](LICENSE).

---

## Acknowledgements

- [Buildroot](https://buildroot.org/) — The build system backbone
- [OP-TEE](https://www.op-tee.org/) — Open Portable Trusted Execution Environment
- [ARM Trusted Firmware](https://www.trustedfirmware.org/) — Secure boot reference implementation
- [RAUC](https://rauc.io/) — Robust Auto-Update Controller
- [tpm2-software](https://github.com/tpm2-software) — TPM 2.0 userspace stack
