# ADR-0006: ARM Trusted Firmware-A and OP-TEE Boot Chain Integration

**Date:** 2026-02-28
**Status:** Accepted
**Milestone:** v0.2.0

---

## Context

FoundationsOS targets a security-hardened profile that requires a hardware-backed
Trusted Execution Environment (TEE) for secure key storage, measured boot PCR
extension, and future Trusted Application (TA) execution. The two supported boards
have different silicon but share the same ARMv8-A security model:

| Board            | SoC     | Core       | TF-A Platform | OP-TEE Platform |
|------------------|---------|------------|---------------|-----------------|
| Raspberry Pi 5   | BCM2712 | Cortex-A76 | `rpi5`        | `rpi5`          |
| Raspberry Pi 3B+ | BCM2837 | Cortex-A53 | `rpi3`        | `rpi3`          |

Two components form the secure world firmware stack:

* **ARM Trusted Firmware-A (TF-A)** — reference implementation of the Trusted
  Boot Firmware specification (TBB). Runs at EL3 and acts as the Secure Monitor,
  handling SMC calls between the Normal and Secure worlds.

* **OP-TEE OS** — Open Portable Trusted Execution Environment. Runs at S-EL1 as
  the Secure Payload (BL32 in the TF-A terminology). Provides secure storage,
  cryptographic services, and the GlobalPlatform TEE API for Trusted Applications.

---

## Decision

### Boot chain

```
VideoCore firmware
      │
      ├─ Loads bl31.bin as armstub (config.txt: armstub=bl31.bin)
      │
      ▼
TF-A BL31  (EL3 — Secure Monitor)
      │
      ├─ Initialises Secure Monitor Call (SMC) vectors
      ├─ Loads OP-TEE OS image (BL32, built at TF-A build time via AARCH64_SP=optee)
      │
      ▼
OP-TEE OS  (S-EL1 — Secure Payload)
      │
      ├─ Initialises TEE core, secure heap, PKCS#11 TA, secure storage
      └─ Returns to TF-A which hands off to BL33 (U-Boot)
            │
            ▼
      U-Boot (EL2 / NS-EL1 — Normal World bootloader)
            │
            ▼
      Linux kernel (EL1 — Normal World OS)
            │
            ├─ tee.ko driver → /dev/tee0 + /dev/teepriv0
            └─ tee-supplicant (REE daemon, provides TA loading & secure storage backend)
```

### Loading mechanism — armstub

Both RPi5 and RPi3B+ firmware support the `armstub` config.txt directive.  
When `armstub=bl31.bin` is present, the VideoCore GPU firmware:

1. Loads `bl31.bin` into SRAM/DRAM at the platform-defined load address.
2. Sets up CPU initial state and jumps to BL31 at EL3.

This is the only firmware-level entry point for EL3 code on both boards;
there is no BL1/BL2 chain as in full TBB (because the VideoCore firmware itself
acts as the root of trust for the boot chain).

### BL32 integration — OP-TEE as Secure Payload Dispatcher

TF-A is configured with `AARCH64_SP=optee`. Buildroot automatically passes the
OP-TEE binary (tee-header_v2.bin + pager files) to the TF-A build as `BL32=…`.
The resulting `bl31.bin` knows the BL32 entry address at compile time.

OP-TEE image files placed in the boot partition:

| File                | Description                              |
|---------------------|------------------------------------------|
| `tee-header_v2.bin` | OP-TEE image header (load descriptor)    |
| `tee-pager_v2.bin`  | OP-TEE pager (core code, runs in SRAM)   |
| `tee-pageable_v2.bin` | Pageable OP-TEE region (DDR)           |

### Memory carve-out (RPi3B+ specific)

RPi3B+ has 1 GiB of RAM. OP-TEE requires a TrustZone DRAM (TZDRAM) region
inaccessible to the Normal World:

```
CFG_TZDRAM_START=0x3f000000   # 1008 MiB — 16 MiB from top
CFG_TZDRAM_SIZE=0x01000000    # 16 MiB
```

The Linux kernel's `memmap` or `mem=` command-line parameter is **not** required
because TF-A/OP-TEE configure the TZASC (TrustZone Address Space Controller) to
enforce the boundary in hardware before Linux starts.

### Normal World driver and supplicant

The Linux kernel is built with `CONFIG_TEE=y` and `CONFIG_OPTEE=y` (added to the
`linux-hardened.config` fragment). This creates:

* `/dev/tee0` — TA invocation interface (used by libteec / client applications)
* `/dev/teepriv0` — supplicant interface (used by tee-supplicant daemon)

`tee-supplicant` is started at boot by `tee-supplicant.service` (installed in
`/etc/systemd/system/`). It handles TA loading from the REE filesystem and provides
the secure storage backend (writes encrypted blobs to `/data/tee`).

---

## Consequences

### Positive

* Hardware-enforced isolation between Normal World (Linux) and Secure World (OP-TEE).
* Enables v0.3.0 TPM measured boot: OP-TEE TA can extend PCRs over the sealed TEE state.
* Enables v0.5.0 disk encryption: LUKS key sealed inside OP-TEE secure storage.
* Enables future PKCS#11 token TA for hardware-backed key operations.

### Negative / Risks

* **RPi5 TF-A platform** (`rpi5`) was added in TF-A 2.9 (Oct 2023). Buildroot
  `2024.02` ships TF-A 2.10.x which includes it. Earlier Buildroot versions will
  need a custom TF-A version override.

* **OP-TEE on RPi5** is functional as of OP-TEE 4.1 (Apr 2024). If using an older
  Buildroot snapshot, pin OP-TEE to `>= 4.1.0` via
  `BR2_TARGET_OPTEE_OS_CUSTOM_VERSION=y` + `BR2_TARGET_OPTEE_OS_CUSTOM_VERSION_VALUE`.

* **TZDRAM sizing on RPi3B+**: 16 MiB carve-out leaves 1008 MiB for Linux. If
  OP-TEE TAs require more secure heap, `CFG_TZDRAM_SIZE` must be increased and the
  Linux `mem=` parameter adjusted accordingly.

* **No Secure Boot chain verification** at this milestone. The VideoCore firmware
  does not verify the signature of `bl31.bin`. Full chain-of-trust verification
  requires HAB / secure boot keys provisioned into the SoC — not applicable on
  consumer RPi hardware. Integrity is provided instead by RAUC bundle signatures
  and IMA/EVM (future milestones).

---

## Alternatives Considered

### A — Skip TF-A, run OP-TEE directly as armstub

OP-TEE can be built as a standalone armstub (`armstub=optee.bin`). This removes
the TF-A EL3 layer. Rejected: loses SMC dispatch infrastructure needed for PSCI
(CPU hotplug, suspend/resume), reduces composability with future TAs that rely on
TF-A's SPMD/FF-A.

### B — Use Hafnium as Secure Partition Manager (SPM)

TF-A 2.8+ supports Hafnium as a SPM for FF-A (Firmware Framework for Arm).
Deferred: adds significant complexity; OP-TEE FF-A support is experimental on RPi.
Reconsider at v1.x.

### C — Use Das U-Boot TEE support without TF-A

U-Boot can integrate with OP-TEE without TF-A by acting as a pseudo-BL31.
Rejected: non-standard, loses EL3 Secure Monitor, not recommended by TF-A or
OP-TEE upstream projects.
