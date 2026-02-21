# Getting Started

## Prerequisites

### Hardware

- Raspberry Pi 5 (any RAM variant)
- MicroSD card (≥ 8 GB, Class 10 or better) or NVMe SSD
- USB serial console (e.g., FTDI 3.3V) for serial debug
- TPM 2.0 module (SPI, e.g., Infineon SLB 9670) — optional for initial bring-up

### Host Build Machine

- Ubuntu 22.04 LTS or Debian 12 (recommended)
- At least 20 GB free disk space (Buildroot downloads and build artifacts)
- At least 4 CPU cores and 8 GB RAM recommended

---

## Step 1: Clone the Repository

```bash
git clone https://github.com/doevelopper/foundationsos.git
cd foundationsos
```

---

## Step 2: Install Host Dependencies

```bash
make setup
# or equivalently:
./scripts/setup-env.sh
```

---

## Step 3: Download Buildroot

Buildroot is downloaded automatically during `make configure`. Alternatively:

```bash
BUILDROOT_VERSION=2024.02
wget https://buildroot.org/downloads/buildroot-${BUILDROOT_VERSION}.tar.gz
tar -xzf buildroot-${BUILDROOT_VERSION}.tar.gz
mv buildroot-${BUILDROOT_VERSION} buildroot
```

---

## Step 4: Configure

```bash
make configure
```

This applies `configs/raspberrypi5_defconfig` to Buildroot.

To customize the configuration:
```bash
make menuconfig           # Buildroot packages
make linux-menuconfig     # Linux kernel options
```

---

## Step 5: Build

```bash
make build
```

> ⏱ First build takes **30–90 minutes** depending on host speed. Subsequent builds are incremental.

Output images are placed in `output/images/`:
- `sdcard.img` — Full SD card image (flash this)
- `sdcard.img.sha256` — SHA-256 checksum
- `rootfs.ext4` — Root filesystem (slot A/B content)

---

## Step 6: Flash

```bash
# Identify your SD card device
lsblk

# Flash (replace /dev/sdX with your device)
make flash DEVICE=/dev/sdX
# or:
./scripts/flash.sh --device /dev/sdX
```

---

## Step 7: Boot

1. Insert the SD card into the Raspberry Pi 5.
2. Connect a USB serial console (115200 8N1).
3. Power on. You should see the TF-A boot log followed by U-Boot and Linux.

Default login: **root** (no password on development builds — harden before production).

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| No serial output | Wrong serial port or cable | Check `/dev/ttyUSB0`, try 115200 |
| Kernel panic at boot | Wrong DTB or rootfs corruption | Re-flash the SD card |
| TPM not found | Module not connected or wrong SPI config | Check SPI wiring and `config.txt` |
| RAUC install fails | Signature mismatch | Verify bundle was signed with correct key |

---

## Next Steps

- [Build Guide](build-guide.md) — Advanced build customization
- [Architecture Overview](architecture/overview.md) — System design
- [Security Model](architecture/security.md) — Threat model and hardening
- [Update Strategy](architecture/update-strategy.md) — OTA updates with RAUC
