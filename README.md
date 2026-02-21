# FoundationsOS

<div align="center">

[![CI](https://github.com/doevelopper/foundationsos/actions/workflows/ci.yml/badge.svg)](https://github.com/doevelopper/foundationsos/actions/workflows/ci.yml)
[![Release](https://github.com/doevelopper/foundationsos/actions/workflows/release.yml/badge.svg)](https://github.com/doevelopper/foundationsos/actions/workflows/release.yml)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![REUSE compliant](https://api.reuse.software/badge/github.com/doevelopper/foundationsos)](https://api.reuse.software/info/github.com/doevelopper/foundationsos)

**A security-hardened embedded Linux OS for Raspberry Pi 5**  
*Built on Buildroot · Secured by TPM2 · Protected by OP-TEE & ARM TF-A · Updated via RAUC*

</div>

---

## Overview

**FoundationsOS** is a production-grade, security-first embedded Linux distribution targeting the **Raspberry Pi 5 (BCM2712)** platform. It is built with [Buildroot](https://buildroot.org/) and integrates a full chain of trust from hardware-backed root of trust to over-the-air update delivery.

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
# Configure for Raspberry Pi 5
make configure

# Build the full image (takes 30–90 min on first run)
make build

# Output images are in output/images/
make images
```

### Flashing

```bash
# Flash to SD card (replace /dev/sdX with your device)
make flash DEVICE=/dev/sdX

# Or use the helper script
./scripts/flash.sh --device /dev/sdX --image output/images/sdcard.img
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
│   └── raspberrypi5/           # Board-specific files
│       ├── rootfs_overlay/     # Files overlaid onto the root filesystem
│       ├── patches/            # Board-specific patches
│       ├── post-build.sh       # Post-build hook
│       ├── post-image.sh       # Post-image hook
│       └── genimage.cfg        # Disk image layout
├── configs/
│   └── raspberrypi5_defconfig  # Buildroot defconfig
├── docs/                       # Project documentation
│   ├── architecture/           # Architecture decision records & diagrams
│   ├── adr/                    # Architecture Decision Records
│   └── *.md                    # Guides and references
├── external/
│   └── package/                # External Buildroot packages
├── keys/                       # Key generation scripts (NO private keys in VCS)
│   ├── rauc/                   # RAUC signing key infrastructure
│   └── optee/                  # OP-TEE key scripts
├── scripts/                    # Build & utility scripts
│   ├── setup-env.sh
│   ├── build.sh
│   └── flash.sh
├── Makefile                    # Top-level convenience targets
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

- [ ] v0.1.0 — Baseline Buildroot image booting on RPi5
- [ ] v0.2.0 — ARM TF-A + OP-TEE integration
- [ ] v0.3.0 — TPM 2.0 measured boot & attestation
- [ ] v0.4.0 — RAUC A/B OTA updates
- [ ] v0.5.0 — Full disk encryption (dm-crypt/LUKS)
- [ ] v0.6.0 — IMA/EVM file integrity
- [ ] v0.7.0 — AppArmor MAC policies
- [ ] v1.0.0 — Production-ready hardened image

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
