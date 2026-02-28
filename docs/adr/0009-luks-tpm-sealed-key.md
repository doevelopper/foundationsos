# ADR-0009: Full Disk Encryption with LUKS2 and TPM-Sealed Key

## Status

Accepted

## Context

The `/data` partition holds persistent device state: RAUC status database,
hawkBit authentication token, application configuration, and logs. These are
sensitive and must be protected against offline attacks (physical access to the
SD card / eMMC without knowledge of the device's firmware state).

## Decision

Encrypt the `/data` partition (partition 4) using **LUKS2** with a 64-byte
random key that is **sealed to the TPM 2.0 using the PCR[0,4,7,8] policy**
established in v0.3.0. The key is never stored in plaintext on any persistent
medium.

## Cryptographic Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| LUKS version | 2 | LUKS2 supports Argon2id PBKDF and integrity protection |
| Cipher | aes-xts-plain64 | Industry standard for block-device encryption |
| Key size | 256 bits (XTS key = 2×128 bits) | Equivalent to AES-128 security |
| Hash | sha256 | Used for anti-forensic stripes |
| PBKDF | argon2id | Memory-hard; resists GPU brute-force |
| PBKDF iter-time | 2000 ms | Acceptable delay at first-boot provisioning |

## TPM Key Hierarchy

The LUKS passphrase is sealed as a **data object** under the SRK
(`0x81000001`, provisioned in v0.3.0):

```
TPM Hierarchy
└── SRK (0x81000001)  Storage Root Key
    └── luks-data sealed object  (public: /etc/tpm2/luks-data.pub)
                                  (private: /etc/tpm2/luks-data.priv)
        Policy: PCR[sha256:0,4,7,8] must match at unseal time
```

The sealed object's **authorization policy** is a PCR policy over:
- `PCR[0]` — TF-A BL31 + U-Boot measurement
- `PCR[4]` — Linux kernel image
- `PCR[7]` — Device tree blob (DTB)
- `PCR[8]` — Active RAUC slot (extended in boot.cmd)

Any change to these measurements (firmware update, tampered kernel/DTB, or
change of boot slot) will cause `tpm2_unseal` to fail, preventing access to
the encrypted partition.

## Boot-Time Flow

```
Power on
  │
  ▼
TF-A BL31 → (extends PCR[0])
  │
  ▼
U-Boot (CONFIG_MEASURED_BOOT)
  → PCR[4] = kernel hash
  → PCR[7] = DTB hash
  → PCR[8] = "a" or "b" (RAUC slot, extended in boot.cmd)
  │
  ▼
Linux boots
  │
  ▼
tpm2-abrmd.service starts (TPM access broker)
  │
  ▼
luks-data.service (ExecStart=/usr/sbin/luks-init.sh)
  ├── First boot: cryptsetup luksFormat → luksOpen → mkfs.ext4
  │              → luks-tpm-seal.sh seal /run/luks/data.key
  │              → shred /run/luks/data.key
  └── Normal boot: luks-tpm-seal.sh unseal /run/luks/data.key
                  → cryptsetup luksOpen /dev/mmcblk0p4 luks-data
                  → shred /run/luks/data.key
  │
  ▼
data.mount (What=/dev/mapper/luks-data, Where=/data)
  │
  ▼
rauc-hawkbit-updater.service, tee-supplicant.service, etc.
  (all write to /data)
```

## First-Boot Provisioning

On the very first boot after flashing a new image:
1. `/dev/mmcblk0p4` does not contain a LUKS header (`cryptsetup isLuks` fails)
2. `luks-init.sh` generates `/run/luks/data.key` (64 bytes, `/dev/urandom`)
3. `cryptsetup luksFormat` writes the LUKS2 header and slot 0
4. `cryptsetup luksOpen` creates `/dev/mapper/luks-data`
5. `mkfs.ext4` creates the filesystem
6. `luks-tpm-seal.sh seal` seals the key under SRK with PCR policy
7. `shred` destroys the runtime key from `/run/luks/`

The sealed object files (`/etc/tpm2/luks-data.{pub,priv}`) are stored in the
root filesystem (read-only partition). The raw 64-byte key never touches the
data partition or any persistent storage.

## Recovery Procedure

If the TPM PCR policy no longer matches (e.g. after a firmware update that
changed PCR[0] or PCR[4]):

1. Prepare a trusted recovery image (same LUKS key, different firmware)
2. Boot from recovery
3. Unseal the key using the **old** firmware's PCRs (or use a backup recovery
   key added at provisioning time: `cryptsetup luksAddKey /dev/mmcblk0p4`)
4. After booting the new firmware, re-seal:
   ```bash
   # On the device with new firmware running:
   luks-tpm-seal.sh seal /tmp/recovery.key
   # Then remove the recovery key slot:
   cryptsetup luksKillSlot /dev/mmcblk0p4 1
   ```

**Recommendation**: always add a recovery key slot (stored offline/in HSM)
at manufacturing time so that PCR-policy failures are recoverable.

## Genimage Layout

The data partition (`/dev/mmcblk0p4`) is pre-formatted as plain ext4 in the
factory image to allow the device to boot before first-boot provisioning.
On first boot, `luks-init.sh` detects the absence of a LUKS header and
re-formats in place as LUKS2. This is safe because the partition contains no
user data at this point.

## Alternatives Considered

| Approach | Verdict |
|----------|---------|
| Full rootfs encryption | Requires initramfs + TPM unlock at early boot; complex for Buildroot; deferred to a future milestone |
| eCryptfs per-file encryption | No LUKS; weaker; no hardware binding |
| Passphrase in `/etc` (plaintext) | Unacceptable — trivially readable from SD card |
| systemd-cryptenroll (tpm2) | Requires systemd ≥248 and `sd-stub`; cleaner but less portable across Buildroot versions |

## Consequences

- **Positive**: data partition encrypted at rest; key never persisted in
  plaintext; key binding to firmware state detects tampering; compatible with
  RAUC OTA (firmware updates followed by re-seal).
- **Negative**: first boot takes ~5 s longer (LUKS formatting + key derivation);
  firmware updates require a re-seal step after upgrade (handled by a future
  post-install hook in v0.6.0+); PCR policy failure requires a recovery key.
