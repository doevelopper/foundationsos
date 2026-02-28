# FoundationsOS Build Guide

## Prerequisites

- Ubuntu 22.04 or Debian 12 host
- At least 30 GB free disk space
- 4+ GB RAM recommended
- Internet connection for initial downloads

## Quick Start

```bash
# Install host dependencies
make setup

# Configure for Raspberry Pi 5 (default)
make configure

# Or configure for Raspberry Pi 3B+
make configure BOARD=raspberrypi3bp

# Build the full image (~30-90 minutes)
make build
```

## Advanced Configuration

### Customizing the Kernel

```bash
make linux-menuconfig
```

### Customizing Packages

```bash
make menuconfig
```

### Building for a Specific Board

```bash
# RPi5 (default)
make configure BOARD=raspberrypi5
make build BOARD=raspberrypi5

# RPi3B+ (64-bit)
make configure BOARD=raspberrypi3bp
make build BOARD=raspberrypi3bp
```

## Build Outputs

After a successful build, images are in `output/<board>/images/`:

| File | Description |
|------|-------------|
| `sdcard.img` | Complete SD card image (flash directly) |
| `rootfs.squashfs` | Root filesystem (for RAUC bundles) |
| `Image` | Linux kernel image |
| `*.dtb` | Device tree blob |

## Flashing

```bash
make flash DEVICE=/dev/sdX BOARD=raspberrypi5
```

## Building RAUC Update Bundles

```bash
make rauc-bundle
```

## Troubleshooting

### Build fails with missing dependencies

Run `make setup` to install all required host packages.

### Out of disk space

Buildroot downloads and build artifacts can consume 15+ GB. Use `make clean` to free space.

### Defconfig errors

Ensure you are using a supported board name: `raspberrypi5` or `raspberrypi3bp`.
