# Top-level Makefile for FoundationsOS
#
# Convenience wrapper around Buildroot's make system.
# Usage:
#   make setup       — install host dependencies
#   make configure   — configure Buildroot for RPi5
#   make build       — build the full image
#   make flash       — flash sdcard.img to DEVICE=/dev/sdX
#   make clean       — clean build artifacts
#   make distclean   — full clean including downloads
#   make rauc-bundle — build a RAUC update bundle
#   make menuconfig  — open Buildroot menuconfig
#   make linux-menuconfig — open Linux kernel menuconfig

BUILDROOT_VERSION  ?= 2024.02
BUILDROOT_DIR      ?= $(CURDIR)/buildroot
BUILDROOT_URL      := https://buildroot.org/downloads/buildroot-$(BUILDROOT_VERSION).tar.gz

OUTPUT_DIR         ?= $(CURDIR)/output
DEFCONFIG          := raspberrypi5_defconfig
BOARD              := raspberrypi5

DEVICE             ?= /dev/sdX

.PHONY: all setup configure build clean distclean flash rauc-bundle menuconfig linux-menuconfig help

all: build

## Download and extract Buildroot if not present
$(BUILDROOT_DIR)/Makefile:
	@echo "[foundationsos] Downloading Buildroot $(BUILDROOT_VERSION)..."
	@mkdir -p $(BUILDROOT_DIR)
	@wget -q --show-progress -O /tmp/buildroot.tar.gz $(BUILDROOT_URL)
	@tar -xzf /tmp/buildroot.tar.gz --strip-components=1 -C $(BUILDROOT_DIR)
	@rm -f /tmp/buildroot.tar.gz
	@echo "[foundationsos] Buildroot ready."

## Install host build dependencies (Debian/Ubuntu)
setup:
	@echo "[foundationsos] Installing host dependencies..."
	@sudo apt-get update -qq
	@sudo apt-get install -y \
		build-essential git wget cpio unzip rsync bc \
		python3 python3-pip python3-setuptools \
		libssl-dev libncurses-dev file \
		device-tree-compiler bison flex \
		gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu \
		parted dosfstools e2fsprogs mtools
	@echo "[foundationsos] Host setup complete."

## Apply the defconfig and configure Buildroot
configure: $(BUILDROOT_DIR)/Makefile
	@echo "[foundationsos] Configuring for $(BOARD)..."
	@$(MAKE) -C $(BUILDROOT_DIR) \
		BR2_EXTERNAL=$(CURDIR)/external \
		O=$(OUTPUT_DIR) \
		$(DEFCONFIG)
	@cp -f configs/$(DEFCONFIG) $(OUTPUT_DIR)/.config
	@echo "[foundationsos] Configuration done. Run 'make build' to start the build."

## Build the complete image
build: $(BUILDROOT_DIR)/Makefile
	@echo "[foundationsos] Starting build (this may take 30-90 minutes)..."
	@$(MAKE) -C $(BUILDROOT_DIR) \
		BR2_EXTERNAL=$(CURDIR)/external \
		O=$(OUTPUT_DIR) \
		all
	@echo "[foundationsos] Build complete. Images in $(OUTPUT_DIR)/images/"

## Open interactive Buildroot menuconfig
menuconfig: $(BUILDROOT_DIR)/Makefile
	@$(MAKE) -C $(BUILDROOT_DIR) O=$(OUTPUT_DIR) menuconfig

## Open Linux kernel menuconfig
linux-menuconfig: $(BUILDROOT_DIR)/Makefile
	@$(MAKE) -C $(BUILDROOT_DIR) O=$(OUTPUT_DIR) linux-menuconfig

## Flash the SD card image
flash:
	@if [ "$(DEVICE)" = "/dev/sdX" ]; then \
		echo "Error: set DEVICE to your target block device, e.g. make flash DEVICE=/dev/sdb"; \
		exit 1; \
	fi
	@./scripts/flash.sh --device $(DEVICE) --image $(OUTPUT_DIR)/images/sdcard.img

## Build a RAUC update bundle
rauc-bundle:
	@echo "[foundationsos] Building RAUC update bundle..."
	@./scripts/build-rauc-bundle.sh
	@echo "[foundationsos] RAUC bundle ready."

## Clean build artifacts (keep downloads)
clean:
	@$(MAKE) -C $(BUILDROOT_DIR) O=$(OUTPUT_DIR) clean 2>/dev/null || true
	@echo "[foundationsos] Clean done."

## Full clean (including downloads)
distclean:
	@rm -rf $(OUTPUT_DIR)
	@echo "[foundationsos] Distclean done."

## Display help
help:
	@echo ""
	@echo "FoundationsOS — Build Targets"
	@echo "──────────────────────────────────────────────────"
	@echo "  setup             Install host build dependencies"
	@echo "  configure         Apply defconfig for RPi5"
	@echo "  build             Build the complete OS image"
	@echo "  menuconfig        Buildroot interactive config"
	@echo "  linux-menuconfig  Linux kernel interactive config"
	@echo "  flash             Flash image (DEVICE=/dev/sdX)"
	@echo "  rauc-bundle       Build RAUC OTA update bundle"
	@echo "  clean             Clean build outputs"
	@echo "  distclean         Full clean (incl. downloads)"
	@echo ""
	@echo "Variables:"
	@echo "  BUILDROOT_VERSION=$(BUILDROOT_VERSION)"
	@echo "  OUTPUT_DIR=$(OUTPUT_DIR)"
	@echo "  DEVICE=$(DEVICE)"
	@echo ""
