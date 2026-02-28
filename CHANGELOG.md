# Changelog

All notable changes to FoundationsOS are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned (v0.3.0)
- TPM 2.0 measured boot: U-Boot extends PCR[0] with bl31.bin, U-Boot, and kernel hash
- OP-TEE TA for TPM PCR sealing / attestation

---

## [0.2.0] — 2026-02-28

ARM Trusted Firmware-A and OP-TEE OS integration for both supported boards.
Establishes the full ARMv8-A security-world boot chain:
VideoCore → TF-A BL31 (EL3) → OP-TEE BL32 (S-EL1) → U-Boot BL33 (EL2) → Linux.

### Added

**ARM Trusted Firmware-A (TF-A)**
- `configs/raspberrypi5_defconfig`: `BR2_TARGET_ARM_TRUSTED_FIRMWARE=y`,
  platform `rpi5`, `AARCH64_SP=optee`, `LOG_LEVEL=20`, `BL31=y`
- `configs/raspberrypi3bp_defconfig`: `BR2_TARGET_ARM_TRUSTED_FIRMWARE=y`,
  platform `rpi3`, `AARCH64_SP=optee`, `RPI3_PRELOADED_DTB_BASE=0x2eff8000`
- Both defconfigs: `BR2_TARGET_ARM_TRUSTED_FIRMWARE_UBOOT_AS_BL33=y` — U-Boot
  is registered as BL33 (Normal World entry) at TF-A compile time

**OP-TEE OS**
- `configs/raspberrypi5_defconfig`: `BR2_TARGET_OPTEE_OS=y`, platform `rpi5`,
  `CFG_ARM64_core=y`, `CFG_TEE_CORE_LOG_LEVEL=2`
- `configs/raspberrypi3bp_defconfig`: `BR2_TARGET_OPTEE_OS=y`, platform `rpi3`,
  `CFG_TZDRAM_START=0x3f000000 CFG_TZDRAM_SIZE=0x01000000` (16 MiB carve-out
  from top of 1 GiB RAM)
- Both defconfigs: `BR2_PACKAGE_OPTEE_CLIENT=y BR2_PACKAGE_OPTEE_CLIENT_SUPPLICANT=y`

**OP-TEE kernel driver**
- `board/raspberrypi5/linux-hardened.config`: `CONFIG_TEE=y CONFIG_OPTEE=y` —
  creates `/dev/tee0` (TA invocation) and `/dev/teepriv0` (supplicant interface)
- `board/raspberrypi3bp/linux-hardened.config`: same

**tee-supplicant systemd service**
- `board/raspberrypi5/rootfs_overlay/etc/systemd/system/tee-supplicant.service`
  — starts `tee-supplicant /dev/teepriv0`; hardened unit (NoNewPrivileges,
  ProtectSystem=strict, DeviceAllow=/dev/teepriv0); writes to `/data/tee`
- `board/raspberrypi3bp/rootfs_overlay/etc/systemd/system/tee-supplicant.service`
  — identical

**Boot partition (genimage.cfg)**
- Both boards: added `tee-header_v2.bin`, `tee-pager_v2.bin`,
  `tee-pageable_v2.bin` to boot.vfat file list (OP-TEE paged image)

**Architecture documentation**
- `docs/adr/0006-tfa-optee-boot-chain.md` — full boot chain diagram, memory
  carve-out rationale, BL32 integration notes, alternatives considered

### Changed

- `board/raspberrypi5/rootfs_overlay/boot/config.txt`: added `armstub=bl31.bin`
  above the `kernel=u-boot.bin` line; added explanatory comment
- `board/raspberrypi3bp/rootfs_overlay/boot/config.txt`: activated
  `armstub=bl31.bin` (was commented out as deferred in v0.1.1)
- `board/raspberrypi5/post-image.sh`: added TF-A `bl31.bin` validation step and
  OP-TEE pager binary validation before genimage invocation
- `board/raspberrypi3bp/post-image.sh`: same
- `configs/raspberrypi5_defconfig`: version banner updated to v0.2.0; added
  boot chain documentation in header comment
- `configs/raspberrypi3bp_defconfig`: same

---

## [0.1.1] — 2026-02-28

Baseline Buildroot image booting on Raspberry Pi 3 Model B+ in AArch64 64-bit mode.
Parity with v0.1.0 security posture: same hardened kernel policy, RAUC A/B, TPM2
userspace, systemd, IMA/EVM, AppArmor, dm-crypt scaffolding.

### Added

**RPi3B+ boot overlay**
- `board/raspberrypi3bp/rootfs_overlay/boot/config.txt` — VideoCore firmware config:
  `arm_64bit=1`, `kernel=u-boot.bin`, `dtoverlay=disable-bt` (reclaim UART0),
  `dtparam=spi=on`, `dtoverlay=tpm-slb9670`, `gpu_mem=16`
- `board/raspberrypi3bp/rootfs_overlay/boot/cmdline.txt` — hardened kernel command
  line: `console=serial0,115200`, `root=PARTLABEL=rootfs_a` (RAUC A/B), `panic=5`,
  `ima_policy=tcb ima_appraise=enforce apparmor=1 security=apparmor`

**IMA policy**
- `board/raspberrypi3bp/rootfs_overlay/etc/ima/ima-policy` — IMA measurement and
  appraisal policy: blocks pseudo-fs, measures all executables and firmware,
  appraises root-owned binaries and kernel modules; in permissive/fix mode for
  v0.1.x (full enforcement at v0.6.0)
- `board/raspberrypi5/rootfs_overlay/etc/ima/ima-policy` — same policy for RPi5

### Fixed

- `board/raspberrypi3bp/rootfs_overlay/boot/config.txt` — removed premature
  `armstub=bl31.bin` reference; TF-A integration deferred to v0.2.0
- `board/raspberrypi3bp/rootfs_overlay/boot/cmdline.txt` — corrected
  `root=/dev/mmcblk0p2` → `root=PARTLABEL=rootfs_a` for RAUC A/B compatibility;
  added `panic=5` and `systemd.unified_cgroup_hierarchy=1`
- `board/raspberrypi3bp/rootfs_overlay/boot/boot.cmd` — added `panic=5` to kernel
  bootargs; added section headers; improved comments
- `board/raspberrypi3bp/linux-hardened.config` — synced with RPi5 fragment:
  added `CONFIG_EVM_EXTRA_SMACK_XATTRS=n`, `CONFIG_MODULE_SIG_ALL=n`,
  `CONFIG_NFT_LOG=y`, `CONFIG_ACPI_CUSTOM_METHOD=n`; noted
  `SHADOW_CALL_STACK` requires Clang/SCS toolchain (deferred)

### Changed

- `.github/workflows/ci.yml` — extended lint/validation to cover RPi3B+:
  ShellCheck on both post-build/post-image scripts; defconfig syntax check and
  RAUC config validation for `raspberrypi3bp_defconfig`; dedicated `defconfig-check`
  job step for RPi3B+ (`O=/tmp/br-rpi3bp`)

---

## [0.1.0] — 2026-02-28

Baseline Buildroot image booting on Raspberry Pi 5.
All security primitives are present in the kernel and userspace; full
integration of the higher-level security stack is staged across subsequent
milestones.

### Added

**Build system**
- `configs/raspberrypi5_defconfig` — Buildroot defconfig for BCM2712 Cortex-A76
  AArch64; `multi_v8_defconfig` kernel base + security fragment; `rpi_arm64`
  U-Boot; `rpi-firmware` package for VideoCore files
- `configs/raspberrypi3bp_defconfig` — Buildroot defconfig for BCM2837 Cortex-A53
  AArch64 (64-bit mode); same security stack
- `Makefile` — board-aware (`BOARD=raspberrypi5|raspberrypi3bp`), per-board
  output directories (`output/<board>/`)

**Kernel security hardening (both boards)**
- `board/raspberrypi5/linux-hardened.config` and `board/raspberrypi3bp/linux-hardened.config`
  Applied as Buildroot config fragment on top of `multi_v8_defconfig`:
  IMA/EVM, AppArmor, dm-verity/dm-crypt, seccomp, KASLR, stack protector,
  kernel lockdown, Yama, TPM 2.0 SPI driver, platform-specific drivers

**U-Boot (both boards)**
- `board/raspberrypi5/uboot-tpm.config` and `board/raspberrypi3bp/uboot-tpm.config`
  FIT image support, RAUC boot-count rollback (bootlimit=3), TPM2 SPI
  scaffolding, FAT environment on boot partition
- `board/raspberrypi5/rootfs_overlay/boot/boot.cmd` and
  `board/raspberrypi3bp/rootfs_overlay/boot/boot.cmd` — U-Boot boot scripts
  with RAUC A/B slot selection and automatic rollback

**RPi5 board overlay**
- `config.txt` — `arm_64bit=1`, `kernel=u-boot.bin`, `gpu_mem=16`,
  `dtoverlay=tpm-slb9670`, headless HDMI/LED settings
- `cmdline.txt` — `ima_policy=tcb`, `ima_appraise=enforce`, `apparmor=1`,
  `root=PARTLABEL=rootfs_a`, cgroup v2
- `genimage.cfg` — GPT: 256 MiB boot + 2×512 MiB rootfs (A/B) + 256 MiB data
- `post-image.sh` — copies boot files, compiles `boot.scr`, runs genimage

**RPi3B+ board overlay**
- `config.txt` — `arm_64bit=1`, `kernel=u-boot.bin`, `dtoverlay=disable-bt`,
  `dtoverlay=tpm-slb9670`
- `cmdline.txt` — `serial0` console, IMA + AppArmor enforcement
- `genimage.cfg` — GPT: 128 MiB boot + 2×512 MiB rootfs (A/B) + 128 MiB data
- `post-image.sh` — copies boot files, compiles `boot.scr`, runs genimage

**Security userspace packages**
- `tpm2-tss`, `tpm2-tools`, `tpm2-abrmd` — TPM 2.0 userspace stack
- `cryptsetup`, `lvm2` — dm-crypt / LUKS encrypted storage
- `ima-evm-utils`, `attr`, `keyutils` — IMA/EVM userspace tools
- `libseccomp` — seccomp filter library
- `openssl`, `wolfssl`, `mbedtls` — cryptographic libraries
- `nftables`, `iptables` — firewall

**RAUC update framework**
- A/B partition strategy, ECDSA P-521 signing infrastructure
- `keys/rauc/gen-keys.sh` — offline CA + signing key generation
- Per-board `system.conf` (`compatible=foundationsos-rpi5` / `foundationsos-rpi3bp`)

**Documentation**
- Architecture overview with RPi5 and RPi3B+ boot chain diagrams
- Security model and threat table, chain of trust diagram
- A/B RAUC update strategy guide
- Getting started guide (build, flash, boot, troubleshooting)
- ADR-0001 through ADR-0005

**CI/CD**
- GitHub Actions: CI (ShellCheck, defconfig check, Trivy security scan)
- GitHub Actions: Release (build + SBOM + GitHub Release on `v*` tag)
- GitHub Actions: Weekly CVE scan + CodeQL

### Security Notes for v0.1.0
- ARM TF-A and OP-TEE are deferred to v0.2.0
- `MODULE_SIG_FORCE=n` for bring-up; enable before production deployment
- Root password is empty by default; configure SSH keys before production use

---

## [0.1.1] — TBD

_Baseline Buildroot image booting on Raspberry Pi 3B+ (AArch64 64-bit mode)._

---

[Unreleased]: https://github.com/doevelopper/foundationsos/compare/v0.2.0...HEAD
[0.1.0]: https://github.com/doevelopper/foundationsos/releases/tag/v0.1.0
[0.1.1]: https://github.com/doevelopper/foundationsos/compare/v0.1.0...v0.1.1
[0.2.0]: https://github.com/doevelopper/foundationsos/compare/v0.1.1...v0.2.0
