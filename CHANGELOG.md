# Changelog

All notable changes to FoundationsOS are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned (v0.6.0)
- IMA/EVM full enforcement: signed file hashes, EVM HMAC keys sealed to TPM

---

## [0.5.0] — 2026-02-28

Full disk encryption of the `/data` partition using **LUKS2** with a random
64-byte key **sealed to the TPM 2.0** under a PCR[0,4,7,8] authorization
policy. The key is never stored in plaintext on any persistent storage medium.
First-boot provisioning is fully automated; subsequent boots unseal the key
from the TPM in under one second.

### Added

**Kernel — hardware AES and XTS cipher support (both boards)**
- `board/raspberrypi5/linux-hardened.config`: `CONFIG_CRYPTO_XTS=y`,
  `CONFIG_CRYPTO_AES_ARM64=y`, `CONFIG_CRYPTO_SHA256=y`,
  `CONFIG_CRYPTO_SHA512=y` — hardware-accelerated AES-XTS for LUKS2
  (`aes-xts-plain64` cipher with 256-bit key)
- `board/raspberrypi3bp/linux-hardened.config`: same additions

**TPM2 LUKS seal/unseal script**
- `scripts/luks-tpm-seal.sh` — seals/unseals a LUKS passphrase into a TPM2
  data-object stored under the SRK (0x81000001).
  `seal <keyfile>`: creates a PCR[sha256:0,4,7,8]-bound data object, writes
  `public` and `private` blobs to `/etc/tpm2/luks-data.{pub,priv}`.
  `unseal <output>`: starts a policy session, verifies current PCRs match the
  recorded policy, loads and unseals the object → `output`. Installed to
  `/usr/sbin/luks-tpm-seal.sh` by `post-build.sh`.

**First-boot LUKS initialization script**
- `scripts/luks-init.sh` — called by `luks-data.service` on every boot.
  First boot (no LUKS header on `/dev/mmcblk0p4`): formats as LUKS2
  (`aes-xts-plain64`, `argon2id`, 2000 ms iter-time), opens container,
  creates ext4, seals key to TPM, shreds runtime key.
  Subsequent boots: unseals key from TPM, opens LUKS, shreds runtime key.
  Installed to `/usr/sbin/luks-init.sh` by `post-build.sh`.

**systemd — LUKS open service (both boards)**
- `board/raspberrypi5/rootfs_overlay/etc/systemd/system/luks-data.service`
  — `Type=oneshot RemainAfterExit=yes`; `Before=data.mount`;
  `Requires=tpm2-abrmd.service`; calls `luks-init.sh`; cleans up
  `/run/luks/data.key` on stop
- `board/raspberrypi3bp/rootfs_overlay/etc/systemd/system/luks-data.service`
  — identical

**systemd — data partition mount unit (both boards)**
- `board/raspberrypi5/rootfs_overlay/etc/systemd/system/data.mount`
  — `What=/dev/mapper/luks-data Where=/data Type=ext4`;
  `Requires=luks-data.service After=luks-data.service`;
  `WantedBy=multi-user.target`
- `board/raspberrypi3bp/rootfs_overlay/etc/systemd/system/data.mount`
  — identical

**crypttab (both boards)**
- `board/raspberrypi5/rootfs_overlay/etc/crypttab` — reference entry for
  manual recovery; normal boot uses `luks-data.service` instead of
  `systemd-cryptsetup`
- `board/raspberrypi3bp/rootfs_overlay/etc/crypttab` — same

**Architecture documentation**
- `docs/adr/0009-luks-tpm-sealed-key.md` — full threat model, cryptographic
  parameters (LUKS2 aes-xts-plain64 argon2id), TPM key hierarchy under SRK,
  boot-time flow diagram, first-boot provisioning sequence, recovery
  procedure (re-seal after firmware update), alternatives considered

**CI — LUKS validation job**
- `.github/workflows/ci.yml`: new `luks-validation` job validates crypttab
  presence, service ordering (`luks-data Before=data.mount`, `data.mount
  Requires=luks-data`), script syntax, ShellCheck, post-build.sh LUKS
  entries, kernel cipher options, ADR presence

### Changed

**Buildroot defconfigs (both boards)**
- Added `BR2_PACKAGE_UTIL_LINUX=y` + `BR2_PACKAGE_UTIL_LINUX_BINARIES=y` —
  provides `wipefs` (partition detection) and other utilities used by
  `luks-init.sh`

**post-build.sh (both boards)**
- Creates `/data` mountpoint in `TARGET_DIR` (chmod 750)
- Installs `luks-init.sh` and `luks-tpm-seal.sh` to `/usr/sbin/` (mode 750)
- Creates `/etc/tpm2/` directory (chmod 700) for sealed key storage

### Security Notes for v0.5.0

- The 64-byte LUKS passphrase is generated from `/dev/urandom` and **never
  written to any persistent storage in plaintext**. After sealing to the TPM
  it exists only in the TPM's non-volatile storage.
- PCR[8] includes the active RAUC slot (`a` or `b`); switching slots via a
  normal RAUC OTA update does NOT change the active slot of the running system
  so the unseal succeeds on the next boot of the same slot. After a RAUC
  update and switch to the new slot, PCR[8] will differ — a **re-seal step**
  is required after applying an OTA update (future v0.6.0 post-install hook).
- A recovery key slot should be added at manufacturing time using
  `cryptsetup luksAddKey` with an offline backup key (see ADR-0009).

---

## [0.4.0] — 2026-02-28

RAUC A/B OTA update pipeline full validation: standard RAUC U-Boot boot
variables, hawkBit cloud connector, mark-good lifecycle service, dual-board
bundle builder, and integration smoke-test harness.

### Added

**hawkBit OTA connector**
- `configs/raspberrypi5_defconfig`: `BR2_PACKAGE_RAUC_HAWKBIT_UPDATER=y` —
  builds `rauc-hawkbit-updater` daemon into the image
- `configs/raspberrypi3bp_defconfig`: same
- `board/raspberrypi5/rootfs_overlay/etc/rauc/hawkbit.conf` — hawkBit client
  configuration template: `hawkbit_server`, `ssl=true`, `ssl_verify=true`,
  `auth_token`, `target_name`, `bundle_download_location=/data/rauc-updates`;
  placeholder values must be replaced per-device before deployment
- `board/raspberrypi3bp/rootfs_overlay/etc/rauc/hawkbit.conf` — same

**systemd — RAUC mark-good service (both boards)**
- `board/raspberrypi5/rootfs_overlay/etc/systemd/system/rauc-mark-good.service`
  — `Type=oneshot RemainAfterExit=yes`; runs `rauc status mark-good` after
  `multi-user.target`; resets `BOOT_x_LEFT` to 3, confirming the boot
  succeeded and preventing spurious rollback
- `board/raspberrypi3bp/rootfs_overlay/etc/systemd/system/rauc-mark-good.service`
  — identical

**systemd — hawkBit updater service (both boards)**
- `board/raspberrypi5/rootfs_overlay/etc/systemd/system/rauc-hawkbit-updater.service`
  — `Type=simple Restart=on-failure RestartSec=30s`; starts after
  `network-online.target` and `rauc-mark-good.service`; only starts when
  `/etc/rauc/hawkbit.conf` is present and non-empty; hardened unit
  (`NoNewPrivileges`, `ProtectSystem=strict`, `PrivateTmp`,
  `ReadWritePaths=/data/rauc-updates`)
- `board/raspberrypi3bp/rootfs_overlay/etc/systemd/system/rauc-hawkbit-updater.service`
  — identical

**Architecture documentation**
- `docs/adr/0008-hawkbit-ota-connector.md` — hawkBit vs alternatives
  (SWUpdate suricatta, custom); full slot lifecycle sequence diagram
  (install → reboot → mark-good → hawkBit feedback → rollback path);
  security considerations (TLS, token rotation, TPM sealing in v0.5.0)

**CI — RAUC validation job**
- `.github/workflows/ci.yml`: new `rauc-validation` job validates both
  `system.conf` files (compatible, bootloader, verity, statusfile,
  max-bundle-download-size), hawkbit.conf presence and ssl fields, all
  new systemd services, runs `test-rauc-bundle.sh --smoke-test`, and
  shellchecks RAUC scripts

**Integration test script**
- `scripts/test-rauc-bundle.sh` — `--smoke-test` mode validates both boards'
  `system.conf`, `hawkbit.conf`, all systemd services, and build scripts
  without needing a built image; bundle mode calls `rauc info` to inspect
  and verify a `.raucb` file; exits non-zero on any failure

### Changed

**RAUC U-Boot boot integration (both boards)**
- `board/raspberrypi5/rootfs_overlay/boot/boot.cmd`: replaced custom
  `rauc_slot` / `bootcount` logic with standard RAUC U-Boot variables
  `BOOT_ORDER`, `BOOT_A_LEFT`, `BOOT_B_LEFT`; handles A-first (normal
  operation) and B-first (post-update) cases; calls `reset` if all
  slots are exhausted
- `board/raspberrypi3bp/rootfs_overlay/boot/boot.cmd`: same treatment
  (serial0 console, bcm2837-rpi-3-b-plus.dtb)

**RAUC system.conf (both boards)**
- Added `statusfile=/data/rauc.db` — persists slot status across reboots
  on the writable `/data` partition
- Added `max-bundle-download-size` — 512 MiB for RPi5, 256 MiB for RPi3B+
- Slot `bootname` changed to uppercase `A`/`B` to match RAUC U-Boot
  variable names `BOOT_A_LEFT` / `BOOT_B_LEFT`

**Bundle builder (`scripts/build-rauc-bundle.sh`)**
- Added `BOARD=` argument (raspberrypi5 or raspberrypi3bp)
- Bundle name now includes board: `foundationsos-<board>-<version>.raucb`
- Prefers `rootfs.ext4` over `rootfs.squashfs` (required for verity format)
- Optionally includes `boot.vfat` as a boot slot when present
- Manifest now embeds per-image SHA-256 checksums
- Output written to `output/` root directory

---

## [0.3.0] — 2026-02-28

TPM 2.0 measured boot and remote attestation.
Every boot stage from TF-A BL31 through the kernel is recorded in TPM PCRs.
Post-boot services log the PCR state and provide tooling to seal, attest, and
verify platform integrity.

### Added

**U-Boot measured boot**
- `board/raspberrypi5/uboot-tpm.config`: `CONFIG_MEASURED_BOOT=y`,
  `CONFIG_MEASURE_DEVICETREE=y` — U-Boot auto-extends PCR[0] with BL31+U-Boot
  hash, PCR[7] with DTB hash via the TCG2 EFI measurement protocol
- `board/raspberrypi3bp/uboot-tpm.config`: same additions

**U-Boot boot script — TPM lifecycle**
- `board/raspberrypi5/rootfs_overlay/boot/boot.cmd`: added `tpm2 startup
  TPM2_SU_CLEAR` at the top of the script (gracefully handles TF-A pre-start);
  sets `tpm_started` env-var to guard subsequent PCR operations; extends
  PCR[8] with the active RAUC slot string (`sha256:${rauc_slot}`) before `booti`
  so slot selection is captured in hardware
- `board/raspberrypi3bp/rootfs_overlay/boot/boot.cmd`: same (serial0 console,
  bcm2837-rpi-3-b-plus.dtb)

**Kernel — security filesystem**
- `board/raspberrypi5/linux-hardened.config`: `CONFIG_SECURITYFS=y`,
  `CONFIG_INTEGRITY_AUDIT=y` — exposes TCG2 event log at
  `/sys/kernel/security/tpm0/binary_bios_measurements`; routes IMA audit events
  to the kernel audit subsystem
- `board/raspberrypi3bp/linux-hardened.config`: same additions

**TPM 2.0 provisioning script**
- `scripts/tpm-provision.sh` — offline provisioning helper that creates the full
  TPM key hierarchy: EK (RSA-2048, persistent at endorsement hierarchy),
  SRK (0x81000001, Storage Root Key, primary under owner hierarchy),
  AIK (0x81000002, ECC P-256 restricted signing key for attestation quotes),
  sealing key (0x81000003, AES-128, bound to PCR[0,4,7,8] policy).
  Writes policy digest to `/etc/tpm2/pcr-policy.digest`. Idempotent: skips
  handles already provisioned.

**TPM 2.0 attestation script**
- `scripts/tpm-attest.sh` — attestation workflow helper with three subcommands:
  `quote` (tpm2_quote over PCR[0,4,7,8,10] signed by AIK 0x81000002),
  `verify` (tpm2_checkquote against reference PCR digest + AIK public key),
  `pcr-show` (tabulated display of all PCR banks using tpm2_pcrread).
  Outputs attestation evidence to `${ATTEST_DIR:-/var/lib/tpm2-attest}`.

**Systemd measured-boot logging service**
- `board/raspberrypi5/rootfs_overlay/etc/systemd/system/tpm2-measured-boot.service`
  — `Type=oneshot RemainAfterExit=yes`; runs after `tpm2-abrmd.service`; reads
  PCR[0,4,7,8,10] via `tpm2_pcrread` and ships to journal via `systemd-cat`;
  also copies the binary TCG2 event log to
  `/var/log/tpm2-event-log/binary_bios_measurements` for persistent storage
- `board/raspberrypi3bp/rootfs_overlay/etc/systemd/system/tpm2-measured-boot.service`
  — identical unit

**Architecture documentation**
- `docs/adr/0007-tpm-measured-boot.md` — PCR assignment layout (PCR[0]=TF-A+U-Boot,
  PCR[4]=kernel image, PCR[5]=kernel cmdline, PCR[7]=DTB, PCR[8]=RAUC slot,
  PCR[10]=IMA); boot-time measurement chain from VideoCore through to Linux;
  remote attestation flow diagram; sealing-key policy rationale; alternatives
  considered (TrustZone-only, no TPM).

### Changed

- `board/raspberrypi5/uboot-tpm.config` and `board/raspberrypi3bp/uboot-tpm.config`:
  updated header comment to reference measured-boot feature additions

### Security Notes for v0.3.0

- `tpm2 startup TPM2_SU_CLEAR` in U-Boot will fail silently if TF-A already
  issued a TPM startup (TF-A ≥ 2.9 does this when `MEASURED_BOOT=1` at TF-A
  level); U-Boot sets `tpm_started=0` in that case which disables the slot-extend
  step — this is a known limitation addressed in v0.4.0 with a `TPM2_SU_STATE`
  resume path.
- PCR[10] is owned exclusively by the Linux IMA subsystem; the boot.cmd script
  never extends it manually.
- Sealing key provisioning (`tpm-provision.sh`) must be run once per physical
  device. Changing any measured firmware invalidates the PCR policy and requires
  re-sealing with the new digest.

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

[Unreleased]: https://github.com/doevelopper/foundationsos/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/doevelopper/foundationsos/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/doevelopper/foundationsos/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/doevelopper/foundationsos/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/doevelopper/foundationsos/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/doevelopper/foundationsos/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/doevelopper/foundationsos/releases/tag/v0.1.0
