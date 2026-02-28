# Changelog

All notable changes to FoundationsOS are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- **Raspberry Pi 3 Model B+ (AArch64) support** (`BOARD=raspberrypi3bp`)
  - `configs/raspberrypi3bp_defconfig` — full Buildroot defconfig targeting Cortex-A53
    in 64-bit mode with TF-A `rpi3`, OP-TEE `rpi3`, TPM2, RAUC, systemd
  - `board/raspberrypi3bp/` — `post-build.sh`, `post-image.sh`, `genimage.cfg`
    (GPT A/B layout: 128 MiB boot + rootfs_a + rootfs_b + 128 MiB data)
  - `board/raspberrypi3bp/rootfs_overlay/boot/config.txt` — `arm_64bit=1`,
    `armstub=bl31.bin`, `dtoverlay=disable-bt`, `dtoverlay=tpm-slb9670`
  - `board/raspberrypi3bp/rootfs_overlay/boot/cmdline.txt` — IMA + AppArmor kernel args
  - `board/raspberrypi3bp/rootfs_overlay/etc/rauc/system.conf` — `compatible=foundationsos-rpi3bp`
  - `board/raspberrypi3bp/rootfs_overlay/etc/systemd/system/tpm2-abrmd.service`
- `Makefile` updated to be board-aware: `make BOARD=raspberrypi3bp configure|build|flash`
  with per-board isolated output directories (`output/<board>/`)
- `docs/architecture/overview.md` — RPi3B+ boot chain, platform comparison table,
  per-board partition layout
- ADR-0002 through ADR-0005 documents added
- Initial repository structure and Buildroot defconfig for Raspberry Pi 5
- ARM Trusted Firmware-A (TF-A) BL31/BL32 integration stubs
- OP-TEE OS integration configuration
- TPM 2.0 support: tpm2-tss, tpm2-tools, tpm2-abrmd systemd service
- RAUC A/B partition update framework with signing infrastructure
- systemd init system with hardened service units
- A/B partition layout via genimage (boot, rootfs_a, rootfs_b, data)
- GitHub Actions CI pipeline (lint, security scan, defconfig check)
- GitHub Actions Release pipeline with SBOM generation
- Weekly security CVE scan workflow
- Comprehensive documentation (architecture, security model, getting-started)
- CONTRIBUTING.md, SECURITY.md, issue templates, PR template, CODEOWNERS

---

## [0.1.0] — TBD

_Initial public release — baseline Buildroot image booting on RPi5._

[Unreleased]: https://github.com/doevelopper/foundationsos/compare/HEAD...HEAD
