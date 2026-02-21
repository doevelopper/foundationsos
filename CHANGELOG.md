# Changelog

All notable changes to FoundationsOS are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
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
