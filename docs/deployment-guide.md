# Deployment Guide

This guide covers production deployment of FoundationsOS on Raspberry Pi 5
and Raspberry Pi 3 Model B+.

## Prerequisites

### Hardware

| Component | Requirement |
|-----------|-------------|
| Board | Raspberry Pi 5 or Raspberry Pi 3 Model B+ |
| Storage | ≥ 8 GB microSD card (Class 10 / UHS-I or better) |
| TPM | SLB9670 TPM 2.0 module (SPI) |
| Serial | USB-to-UART adapter (for initial provisioning) |
| Network | Ethernet connection (for OTA updates) |

### Build Host

Build the production image following [Getting Started](getting-started.md):

```bash
git clone https://github.com/doevelopper/foundationsos.git
cd foundationsos
make setup
make configure BOARD=raspberrypi5   # or BOARD=raspberrypi3bp
make build     BOARD=raspberrypi5
```

## Flashing

```bash
# Identify your SD card device (e.g., /dev/sdX or /dev/mmcblkX)
lsblk

# Flash the image
make flash BOARD=raspberrypi5 DEVICE=/dev/sdX
```

> ⚠️ **Double-check the device path** — flashing to the wrong device
> will destroy data.

## First-Boot Provisioning

### 1. Connect Serial Console

```bash
# RPi5: /dev/ttyAMA10 at 115200 baud
# RPi3B+: serial0 at 115200 baud
screen /dev/ttyUSB0 115200
```

### 2. TPM Provisioning

On first boot, provision the TPM with the required key hierarchy:

```bash
# Run the provisioning script
/usr/local/bin/tpm-provision.sh

# This creates:
#   0x81000001 — Storage Root Key (SRK)
#   0x81000002 — Attestation Identity Key (AIK)
#   0x81000003 — Sealing Key (for LUKS/EVM)
```

### 3. LUKS Data Partition Setup

If using encrypted storage:

```bash
# Initialize the LUKS partition sealed to TPM PCR policy
/usr/local/bin/luks-init.sh

# Seal the LUKS key to TPM
/usr/local/bin/luks-tpm-seal.sh
```

### 4. SSH Key Deployment

FoundationsOS disables password authentication. Deploy SSH keys:

```bash
# From your workstation
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@<device-ip>
```

Or place the public key in the rootfs overlay before building:
```
board/<board>/rootfs_overlay/root/.ssh/authorized_keys
```

### 5. Verify Security Posture

Run the on-target security audit:

```bash
/usr/local/bin/security-audit.sh --verbose
```

All checks should pass. Address any failures before putting the
device into production.

## OTA Updates

### Building an Update Bundle

```bash
make rauc-bundle BOARD=raspberrypi5
# Output: output/raspberrypi5/images/foundationsos-<version>.raucb
```

### Deploying via hawkBit

1. Configure the hawkBit server URL in `/etc/rauc/hawkbit.conf`
2. Assign the bundle to target devices in the hawkBit management UI
3. The `rauc-hawkbit-updater` service polls and applies updates automatically
4. On successful boot, `rauc-mark-good.service` confirms the slot

### Manual Update

```bash
rauc install /path/to/foundationsos-<version>.raucb
reboot
```

### Rollback

If the new slot fails health checks, RAUC automatically rolls back to the
previous slot on the next boot. Manual rollback:

```bash
rauc status
rauc switch-slot <slot-name>
reboot
```

## Key Rotation

### RAUC Signing Key

```bash
# Generate new key pair
cd keys/rauc
./generate-rauc-keys.sh

# Re-sign bundles with the new key
make rauc-bundle BOARD=raspberrypi5
```

### IMA/EVM Keys

```bash
# Generate new IMA signing keys
scripts/generate-ima-keys.sh

# Re-sign the rootfs
scripts/ima-sign-rootfs.sh <rootfs-path>
```

### TPM Key Re-provisioning

If TPM keys need replacement (e.g., after hardware servicing):

```bash
# Clear and re-provision
tpm2_clear
/usr/local/bin/tpm-provision.sh
/usr/local/bin/luks-tpm-seal.sh
```

## Monitoring

### System Health

```bash
# Service status
systemctl status tpm2-abrmd tee-supplicant rauc sshd

# AppArmor enforcement
aa-status

# IMA measurement log
cat /sys/kernel/security/ima/ascii_runtime_measurements

# RAUC slot status
rauc status
```

### Security Audit (Periodic)

Schedule periodic security audits via systemd timer:

```ini
# /etc/systemd/system/security-audit.timer
[Unit]
Description=Periodic security audit

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

### Remote Attestation

Use TPM remote attestation to verify platform integrity:

```bash
/usr/local/bin/tpm-attest.sh --quote
# Send the quote + PCR log to your attestation server
```

## Troubleshooting

| Symptom | Cause | Resolution |
|---------|-------|------------|
| Boot hangs at U-Boot | TPM not initialized | Check SPI wiring; run `tpm2_startup -c` from rescue shell |
| LUKS unlock fails | TPM PCR mismatch | Re-seal key after legitimate system changes |
| RAUC update rejected | Bundle signature invalid | Verify signing key matches device CA cert |
| AppArmor denials in journal | Profile too restrictive | Check `journalctl -k \| grep apparmor`; update profile |
| IMA appraisal fails | Unsigned binary | Re-sign rootfs with `ima-sign-rootfs.sh` |
| SSH connection refused | Key not deployed | Deploy SSH key; check sshd config |

## References

- [Getting Started](getting-started.md)
- [Build Guide](build-guide.md)
- [Architecture Overview](architecture/overview.md)
- [Security Model](architecture/security.md)
- [ADR-0012: Production Hardening](adr/0012-production-hardening.md)
