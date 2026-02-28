# ADR-0007: TPM 2.0 Measured Boot and Attestation

**Date:** 2026-02-28
**Status:** Accepted
**Milestone:** v0.3.0

---

## Context

A security-hardened embedded Linux system must be able to prove to a remote
verifier (or to itself) that it booted from a known-good, unmodified firmware
and software stack. This property is called **platform attestation**.

FoundationsOS implements attestation via the TPM 2.0 **Measured Boot** model:
each component in the boot chain hashes the next component and records the hash
in a TPM Platform Configuration Register (PCR) before transferring control.
The final PCR state is a cryptographic summary of the entire boot chain and
cannot be forged without the TPM.

---

## Decision

### Measurement chain

```
VideoCore firmware (root of trust — cannot be measured by TPM)
       │
       ▼  loads as armstub
TF-A BL31 (EL3)
  → Extends PCR[0] with TF-A binary hash (platform_setup_measurements)
       │
       ▼  PSCI handoff to BL33
U-Boot (BL33)  —  CONFIG_MEASURED_BOOT=y
  → PCR[0]  U-Boot binary (via tpm2_measure_data)
  → PCR[4]  Kernel Image / FIT image payload (autoboot_command measures each image)
  → PCR[5]  U-Boot environment (bootargs at time of kernel handoff)
  → PCR[7]  Device Tree Blob (CONFIG_MEASURE_DEVICETREE=y)
  → PCR[8]  RAUC slot name ("a" or "b") — extended by boot.cmd explicitly
       │
       ▼  booti
Linux kernel
  → PCR[10] IMA measurement log aggregate — extended on every file open
             (IMA policy: measure func=BPRM_CHECK, FILE_MMAP, MODULE_CHECK)
```

### PCR bank

SHA-256 is the only bank used (`sha256:`). The SHA-1 bank is left unused and
should be disabled in firmware if possible (deprecated, collision-vulnerable).

### PCR assignment rationale

| PCR | Owner     | Content                          | Rationale                             |
|-----|-----------|----------------------------------|---------------------------------------|
| 0   | TF-A/U-Boot | Platform firmware (BL31 + U-Boot) | Standard TCG PC Client PCR 0       |
| 4   | U-Boot    | Kernel Image (boot code)         | Standard TCG PC Client PCR 4          |
| 5   | U-Boot    | Boot environment / cmdline       | Standard TCG PC Client PCR 5          |
| 7   | U-Boot    | Device Tree Blob                 | Platform config; matches UEFI PCR 7   |
| 8   | boot.cmd  | RAUC slot name ("a" or "b")      | Binds attestation to specific rootfs  |
| 10  | Linux IMA | File integrity measurements      | Standard IMA PCR; do not extend manually |

PCRs 1–3, 6, 9, 11–23 are unused at this milestone.

### U-Boot measured boot implementation

`CONFIG_MEASURED_BOOT=y` in `uboot-tpm.config` activates U-Boot's built-in
TCG2 measured boot subsystem:

1. U-Boot initialises the TPM via `tpm2 startup TPM2_SU_CLEAR` at the start
   of `boot.cmd` (or TF-A may have already done this — U-Boot handles the
   `TPM_RC_INITIALIZE` error gracefully).
2. Before loading each image, U-Boot calls `tcg2_measure_data()` which:
   a. Hashes the image with SHA-256.
   b. Calls `TPM2_CC_PCR_Extend` to extend the appropriate PCR.
   c. Appends a TCG2 event log entry (EV_EFI_VARIABLE-style descriptor).
3. The TCG2 event log is passed to Linux via the device tree
   (`/proc/device-tree/chosen/linux,tpm-early-log`) and made accessible at
   `/sys/kernel/security/tpm0/binary_bios_measurements`.

`CONFIG_MEASURE_DEVICETREE=y` causes the DTB to be measured into PCR[7].

### TPM startup in boot.cmd

```sh
if tpm2 startup TPM2_SU_CLEAR; then
    setenv tpm_started 1
else
    setenv tpm_started 0
fi
```

`TPM2_SU_CLEAR` (vs `TPM2_SU_STATE`) is used because:
- The system does not use TPM State Save (no hibernate/suspend-to-disk).
- Clear mode re-initialises PCRs to zero, ensuring fresh measurements.
- If TF-A already called Startup, U-Boot silently accepts the TPMA_SESSION
  error and PCR state is preserved.

PCR[8] is explicitly extended with the RAUC slot name so a quote can prove
which A/B partition was booted:

```sh
tpm2 pcr_extend 8 sha256 ${rauc_slot}
```

### Attestation flow

```
Target device                          Remote verifier
──────────────                         ───────────────
1. tpm-provision.sh
   - Create AIK (ECC P-256, restricted signing)
   - Persist at 0x81000002
   - Export aik.pub  ──────────────────────► Store aik.pub + expected PCR baseline

2. tpm-attest.sh quote --nonce <N>
   ◄─────────────────────────────────────── Provide fresh nonce N
   - tpm2_quote with AIK over PCR[0,4,7,8]
   - Returns: quote.bin, quote.sig, pcr-values.bin

   quote.bin + quote.sig + pcr-values.bin ─► tpm2_checkquote --public aik.pub
                                              Compare PCR values vs baseline
                                              Accept or reject boot state
```

The nonce prevents replay attacks. The AIK is a **restricted** signing key —
it can only sign data produced by the TPM itself (quotes), not arbitrary data.

### Sealing policy (v0.5.0 preview)

`tpm-provision.sh` creates a sealing key bound to `PCR[0,4,7,8]` policy.
At v0.5.0, the LUKS master key will be sealed under this policy, so it can
only be unsealed when the system has booted through the exact same firmware
chain that existed at provisioning time.

### Linux kernel configuration

`CONFIG_SECURITYFS=y` exposes:
- `/sys/kernel/security/ima/` — IMA measurement list and policy interface
- `/sys/kernel/security/tpm0/binary_bios_measurements` — TCG2 event log
- `/sys/kernel/security/apparmor/` — AppArmor policy

`CONFIG_INTEGRITY_AUDIT=y` routes IMA/EVM violations to the kernel audit log.

### tpm2-measured-boot.service

A `Type=oneshot` systemd service reads and journals the PCR values + event log
on every boot. This provides:
- An auditable record of each boot's measurement state.
- A baseline for operators to detect unexpected PCR changes.
- Input for future automated attestation workflows.

---

## Consequences

### Positive

- Any modification to TF-A, U-Boot, kernel, DTB, or RAUC slot changes PCR
  values, making it detectable via remote attestation.
- IMA PCR[10] additionally covers every file executed after kernel handoff.
- The attestation architecture is compatible with the RATS (Remote Attestation
  Procedures) WG protocols (RFC 9334).

### Negative / Risks

- **No hardware root of trust for VideoCore firmware**: The RPi VideoCore
  firmware is not measured by the TPM because it runs before the TPM is
  initialised. This is a fundamental constraint of the RPi platform (no
  eFuse-based Secure Boot). Operators must trust the SD card / eMMC contents.

- **TPM startup ordering**: `tpm2 startup TPM2_SU_CLEAR` in boot.cmd will
  fail gracefully if TF-A already called it. If the command fails for any
  other reason (SPI not ready, TPM fault), `tpm_started=0` and PCR[8] is not
  extended — boot continues but attestation will show an unexpected PCR[8] value.

- **PCR[10] is IMA-managed**: Do not extend PCR[10] from boot.cmd or any
  userspace script; IMA owns it exclusively.

- **Sealing key invalidation**: If firmware is updated (new TF-A, U-Boot,
  kernel), PCR values change and any secret sealed under the old PCR policy
  cannot be unsealed. A reprovisioning procedure (re-run `tpm-provision.sh`
  after validating the new boot chain) is required.

---

## Alternatives Considered

### A — Use U-Boot's built-in TPM measured boot only (no explicit PCR[8])

Simpler boot.cmd. Rejected: without PCR[8], a quote cannot distinguish which
RAUC slot was active, making A/B attestation impossible.

### B — Extend all PCRs from an OP-TEE TA

Move all PCR extension logic into an OP-TEE Trusted Application. Deferred:
adds TA development overhead; U-Boot's CONFIG_MEASURED_BOOT already covers
the pre-Linux portion correctly.

### C — Use IMA template `ima-sig` for all measurements

Requires all files to be signed with an IMA signing key before deployment.
Deferred to v0.6.0 (IMA/EVM full enforcement milestone).
