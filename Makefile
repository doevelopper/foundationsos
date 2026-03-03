# Top-level Makefile for FoundationsOS
#
# Convenience wrapper around Buildroot's make system.
# Usage:
#   make setup                              — install host dependencies
#   make configure                          — configure for default board (RPi5)
#   make configure BOARD=raspberrypi3bp     — configure for RPi3B+ (64-bit)
#   make build                              — build the full image
#   make flash DEVICE=/dev/sdX              — flash SD card image
#   make clean                              — clean build artifacts
#   make distclean                          — full clean including downloads
#   make rauc-bundle                        — build a RAUC update bundle
#   make menuconfig                         — open Buildroot menuconfig
#   make linux-menuconfig                   — open Linux kernel menuconfig
#
# Supported boards (BOARD=):
#   raspberrypi5    — Raspberry Pi 5 (BCM2712, Cortex-A76, default)
#   raspberrypi3bp  — Raspberry Pi 3 Model B+ (BCM2837, Cortex-A53, AArch64)

MAKE_HELPERS_DIRECTORY := helpers/

ROOT			       := $(dir $(abspath $(firstword $(MAKEFILE_LIST))))

define receipe
	make -C "$(OUTPUT)/buildroot" BR2_EXTERNAL="$(ROOT)" O="$(OUTPUT)" $(1)
endef

include ${MAKE_HELPERS_DIRECTORY}define.mk
include ${MAKE_HELPERS_DIRECTORY}macros.mk
include ${MAKE_HELPERS_DIRECTORY}versioning.mk

DEVICE             ?= /dev/sdX

# .NOTPARALLEL: $(SUPPORTED_TARGETS) $(TARGETS_CONFIG) allow parallel execution of targets, but not for the same target

## ####################################################################################################
## #
## #				Buildroot RT Infrastructure setup
## #
## ####################################################################################################


$(BLRT_PACKAGE_DIR)/buildroot-$(BLRT_VERSION).tar.gz.sign:
	$(Q)$(call MESSAGE,"BLRT [Downloading signature $@ ]")
	$(Q)mkdir -pv $(BLRT_PACKAGE_DIR)
	$(Q)mkdir -pv $(BLRT_ARTIFACTS_DIR)
	curl --output $@ https://buildroot.org/downloads/buildroot-$(BLRT_VERSION).tar.gz.sign

$(BLRT_PACKAGE_DIR)/buildroot-$(BLRT_VERSION).tar.gz: | $(BLRT_PACKAGE_DIR)/buildroot-$(BLRT_VERSION).tar.gz.sign
	$(Q)$(call MESSAGE,"BLRT [Downloading build tool $@ ]")
	$(Q)curl --output $@ https://buildroot.org/downloads/buildroot-$(BLRT_VERSION).tar.gz

$(BLRT_PACKAGE_DIR)/buildroot-$(BLRT_VERSION): | $(BLRT_PACKAGE_DIR)/buildroot-$(BLRT_VERSION).tar.gz
#	$(Q)$(CMD_PREFIX)$(call MESSAGE,"BLRT [Cloning latest buildroot as buildroot-$(BLRT_VERSION)] $@ ")
#	$(Q)git clone https://github.com/buildroot/buildroot.git $@
# if [ ! -d $@ ]; then
#   git clone -b $BUILDROOT_VERSION https://github.com/buildroot/buildroot.git $@ --depth 1
# fi
	$(Q)$(CMD_PREFIX)$(call MESSAGE,"BLRT [Extracting buildroot-$(BLRT_VERSION)] $@ ")
	$(Q)cd $(BLRT_PACKAGE_DIR) && if [ ! -d $@ ]; then tar xf $(BLRT_PACKAGE_DIR)/buildroot-$(BLRT_VERSION).tar.gz; fi

$(BLRT_PACKAGE_DIR)/.buildroot-downloaded: $(BLRT_PACKAGE_DIR)/buildroot-$(BLRT_VERSION)
	$(Q)$(call MESSAGE,"BLRT [Caching downloaded files in $(BLRT_DL_DIR).]")
	$(Q)touch $@

## useful to patch version of package to be downloaded...  this patch preceed <package>-patch ....
$(BLRT_PACKAGE_DIR)/.buildroot-patched: $(BLRT_PACKAGE_DIR)/.buildroot-downloaded
	$(Q)$(call MESSAGE,"BLRT [Patching buildroot-$(BLRT_VERSION)]")
	$(Q)for p in $(sort $(wildcard buildroot-patches/*.patch)); do \
		echo "Applying $${p}"; \
		patch -d $(BLRT_PACKAGE_DIR)/buildroot-$(BLRT_VERSION) --remove-empty-files -p1 < $${p} || exit 237; \
		[ ! -x $${p%.*}.sh ] || $${p%.*}.sh $(BLRT_PACKAGE_DIR)/buildroot-$(BLRT_VERSION); \
	done;
	$(Q)touch $@

$(BLRT_PACKAGE_DIR)/.others-patched: $(BLRT_PACKAGE_DIR)/.buildroot-patched
	$(Q)$(call MESSAGE,"BLRT [Apply our patches that either haven't been submitted or merged upstream in buildroot-$(BLRT_VERSION)] packages")
#	$(BLRT_DIR)/support/scripts/apply-patches.sh $(BLRT_OOSB)/buildroot-$(BLRT_VERSION) $(BLRT_EXT)/patches/buildroot || exit 1
	$(Q)touch $@


### ####################################################################################################
### #
### #								Goals declaration
### #
### ####################################################################################################	


$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-configure): %-configure: $(BLRT_PACKAGE_DIR)/.others-patched
	$(Q)$(call MESSAGE,"[  Generating configuration for $*]")
	$(Q)$(BLRT_MAKE) $(BLRT_MAKEARGS) BR2_CCACHE_DIR=$(BLRT_PACKAGE_DIR)/cache/cc/$* O=$(BLRT_OOSB)/$*-build-artifacts  $*_defconfig
#	$(Q)if [ ! -f $(BLRT_OOSB)/$*-build-artifacts/.config ] then; \
# 			$(MAKE) $(BLRT_MAKEARGS) O=$(BLRT_OOSB)/$*-build-artifacts  $*_defconfig \
# 		else \
# 			$(call MESSAGE,"BLRT [configuration for $* alredy done]") \
#		fi

# 2>&1 | tee $(BLRT_OOSB)/$*-build-artifacts/$(DATE)_buildroot_$@_output.log	


$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-compile): %-compile:
	$(Q)$(call MESSAGE,"[  Compiling artifacts for targets $*]")
	$(Q)$(BLRT_MAKE) $(BLRT_MAKEARGS) BR2_CCACHE_DIR=$(BLRT_PACKAGE_DIR)/cache/cc/$* O=$(BLRT_OOSB)/$*-build-artifacts
	$(Q)mkdir -pv $(BLRT_ARTIFACTS_DIR)
	$(Q)$(call MESSAGE,"[ Copying artifacts to $(BLRT_ARTIFACTS_DIR)/$*]")
	$(Q)if [ -d $(BLRT_ARTIFACTS_DIR)/$* ]; then rm -Rf $(BLRT_ARTIFACTS_DIR)/$* && mkdir -pv $(BLRT_ARTIFACTS_DIR)/$*; fi
	$(Q)cp -R $(BLRT_OOSB)/$*-build-artifacts/images $(BLRT_ARTIFACTS_DIR)/$*
	$(Q)$(call MESSAGE,"[  Copying binaries to tftp server]")
	$(Q)rm -f /srv/tftp/*
	$(Q)cp  $(BLRT_OOSB)/$*-build-artifacts/images/u-boot.bin /srv/tftp/ 2>/dev/null || :
	$(Q)cp --update=none $(BLRT_OOSB)/$*-build-artifacts/images/*.dtb /srv/tftp/
	$(Q)cp --update=none $(BLRT_OOSB)/$*-build-artifacts/images/*mage /srv/tftp/
	$(Q)$(call MESSAGE,"[  Artifacts :]")
	$(Q)du -sch --time $(BLRT_OOSB)/$*-build-artifacts/images/*


$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-unit-test): %-unit-test: %-compile
	$(Q)$(call MESSAGE,"[  Running Unit test for targets $*]")

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-integration-test): %-integration-test: %-unit-test
	$(Q)$(call MESSAGE,"[  Running Integration test for targets $* board]")

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-menuconfig): %-menuconfig:
	$(Q)$(call MESSAGE,"BLRT [Change buildroot configuration for $*]")
	$(Q)$(MAKE) $(BLRT_MAKEARGS) BR2_CCACHE_DIR=$(BLRT_PACKAGE_DIR)/cache/cc/$* O=$(BLRT_OOSB)/$*-build-artifacts $(subst $*-,,$@)
	$(Q)echo
	$(Q)echo "!!! Important !!!"
	$(Q)echo "1. $(DEFCONFIG_DIR_FULL)/$*_defconfig has $(TERM_RED) NOT/NIET/NADA $(TERM_RESET) been updated."
	$(Q)echo "   Changes will be lost if you run 'make distclean'."
	$(Q)echo "   Run $(TERM_BOLD) 'make $*-savedefconfig' $(TERM_RESET) to update."
	$(Q)echo "2. ERROR: Buildroot normally requires you to run 'make clean' and 'make' after"
	$(Q)echo "   changing the configuration. You don't technically have to do this,"
	$(Q)echo "   but if you're new to Buildroot, it's best to be safe."

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-linux-menuconfig): %-linux-menuconfig:
# #	@if grep -q 'BR2_LINUX_KERNEL=y'
	$(Q)$(call MESSAGE,"[ Change the Linux kernel configuration.] $*")
	$(Q)$(MAKE) $(BLRT_MAKEARGS) BR2_CCACHE_DIR=$(BLRT_PACKAGE_DIR)/cache/cc/$* O=$(BLRT_OOSB)/$*-build-artifacts $(subst $*-,,$@)
	$(Q)$(MAKE) $(BLRT_MAKEARGS) BR2_CCACHE_DIR=$(BLRT_PACKAGE_DIR)/cache/cc/$* O=$(BLRT_OOSB)/$*-build-artifacts linux-savedefconfig
	$(Q)echo
	$(Q)echo Going to update your $(BR2_EXTERNAL_CFSOS_PATH)/board/$*/configs/linux.config. If you do not have one,
	$(Q)echo you will get an error shortly. You will then have to make one and update,
	$(Q)echo your buildroot configuration to use it.
	$(Q)echo
	$(Q)$(MAKE) $(BLRT_MAKEARGS) BR2_CCACHE_DIR=$(BLRT_PACKAGE_DIR)/cache/cc/$* O=$(BLRT_OOSB)/$*-build-artifacts linux-update-defconfig	

# target-finalize    target-post-image
$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-target-clean): %-target-clean:
	$(Q)$(call MESSAGE,"[ Clean only  $*'s target in buildroot.]")
	#$(Q)rm -rf $(BLRT_OOSB)/$*-build-artifacts/
	#$(Q)rm -rf $(BLRT_OOSB)/$*-build-artifacts/

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-linux-rebuild): %-linux-rebuild:
	$(Q)$(call MESSAGE,"BLRT [Rebuilding after $(call UC, $(word 1,$(subst -, ,$(subst $*-,,$@)))) $* configuration change!]")
	$(Q)$(MAKE) $(BLRT_MAKEARGS) BR2_CCACHE_DIR=$(BLRT_PACKAGE_DIR)/cache/cc/$* O=$(BLRT_OOSB)/$*-build-artifacts $(subst $*-,,$@)

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-uboot-menuconfig): %-uboot-menuconfig:
	$(Q)$(call MESSAGE,"[ Change the Bootloader configuration.] $*")
#	@if grep -q 'BR2_TARGET_UBOOT=y' $(BLRT_OOSB)/$*-build-artifacts/.config; then
	$(Q)$(MAKE) $(BLRT_MAKEARGS) BR2_CCACHE_DIR=$(BLRT_PACKAGE_DIR)/cache/cc/$* O=$(BLRT_OOSB)/$*-build-artifacts $(subst $*-,,$@)
	$(Q)$(MAKE) $(BLRT_MAKEARGS) BR2_CCACHE_DIR=$(BLRT_PACKAGE_DIR)/cache/cc/$* O=$(BLRT_OOSB)/$*-build-artifacts uboot-savedefconfig
	$(Q)echo
	$(Q)echo Going to update your $(BR2_EXTERNAL_CFSOS_PATH)/board/$*/configs/uboot.config. If you do not have one,
	$(Q)echo you will get an error shortly. You will then have to make one and update,
	$(Q)echo your buildroot configuration to use it.
	$(Q)$(MAKE) $(BLRT_MAKEARGS) BR2_CCACHE_DIR=$(BLRT_PACKAGE_DIR)/cache/cc/$* O=$(BLRT_OOSB)/$*-build-artifacts uboot-update-defconfig	
#	else 
#		echo "--- (UBOOT not activated SKIPPING $@ ---" ;
#	fi	

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-uboot-rebuild): %-uboot-rebuild:
	$(Q)$(call MESSAGE,"BLRT [Rebuilding after $(call UC, $(word 1,$(subst -, ,$(subst $*-,,$@)))) $* configuration change!]")
	$(Q)$(MAKE) $(BLRT_MAKEARGS) BR2_CCACHE_DIR=$(BLRT_PACKAGE_DIR)/cache/cc/$* O=$(BLRT_OOSB)/$*-build-artifacts $(subst $*-,,$@)

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-busybox-menuconfig): %-busybox-menuconfig:
	$(Q)$(call MESSAGE,"BLRT [Generating $(subst $*-,,$@) configuration for $*]")
	$(Q)$(call MESSAGE,"[ Change the Busybox configuration.] $*")
	$(Q)$(MAKE) $(BLRT_MAKEARGS) BR2_CCACHE_DIR=$(BLRT_PACKAGE_DIR)/cache/cc/$* O=$(BLRT_OOSB)/$*-build-artifacts $(subst $*-,,$@)
	$(Q)echo
	$(Q)echo Going to update your $(BR2_EXTERNAL_CFSOS_PATH)/board/$*/configs/busybox.config. If you do not have one,
	$(Q)echo you will get an error shortly. You will then have to make one and update,
	$(Q)echo your buildroot configuration to use it.
	$(Q)echo
	$(Q)$(MAKE) $(BLRT_MAKEARGS) BR2_CCACHE_DIR=$(BLRT_PACKAGE_DIR)/cache/cc/$* O=$(BLRT_OOSB)/$*-build-artifacts busybox-update-config

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-busybox-rebuild): %-busybox-rebuild:
	$(Q)$(call MESSAGE,"BLRT [Rebuilding after $(call UC, $(word 1,$(subst -, ,$(subst $*-,,$@)))) $* configuration change!]")
	$(Q)$(MAKE) $(BLRT_MAKEARGS) BR2_CCACHE_DIR=$(BLRT_PACKAGE_DIR)/cache/cc/$* O=$(BLRT_OOSB)/$*-build-artifacts $(subst $*-,,$@)

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-savedefconfig): %-savedefconfig:
	$(Q)$(call MESSAGE,"BLRT [Saving $*] default config")
	$(Q)$(MAKE) $(BLRT_MAKEARGS) BR2_CCACHE_DIR=$(BLRT_PACKAGE_DIR)/cache/cc/$* O=$(BLRT_OOSB)/$*-build-artifacts savedefconfig BR2_DEFCONFIG=$(DEFCONFIG_DIR_FULL)/$*_defconfig

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-artifacts-release): %-artifacts-release: %-integration-test
	$(Q)$(call MESSAGE,"[  Packaging $* board's artefacts]")

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-fit-sigh): %-fit-sigh:
	$(Q)$(call MESSAGE,"[  Signing FIT image for $* board]")


## ##################################################################################################################################
## #
## #                                     BR2 Clean goals
## #
## ##################################################################################################################################

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-clean): %-clean:
	$(Q)$(call MESSAGE,"[ Delete all files created by $*'s build]")
	$(Q)$(MAKE) $(BLRT_MAKEARGS) BR2_CCACHE_DIR=$(BLRT_PACKAGE_DIR)/cache/cc/$* O=$(BLRT_OOSB)/$*-build-artifacts $(subst $*-,,$@)

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-distclean): %-distclean:
	$(Q)$(call MESSAGE,"[ Delete all non-source files (including .config) of $*'s build]")
# # $(Q)$(MAKE) $(BLRT_MAKEARGS) BR2_CCACHE_DIR=$(BLRT_PACKAGE_DIR)/cache/cc/$* O=$(BLRT_OOSB)/$*-build-artifacts $(subst $*-,,$@)
# # $(Q)$(call MESSAGE,"BLRT [Re-generating configuration for $*]")
# # $(Q)$(MAKE) $(BLRT_MAKEARGS) BR2_CCACHE_DIR=$(BLRT_PACKAGE_DIR)/cache/cc/$* O=$(BLRT_OOSB)/$*-build-artifacts  $*_defconfig
	$(call SHELL_REMOVE_DIR,${BUILD_BASE})

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-realclean): %-realclean:
	$(Q)$(call MESSAGE,"[ Wiping everything ]")
	$(Q)rm -fr $(BLRT_OOSB)/$*-build-artifacts
	$(Q)rm -f br.log


## ##################################################################################################################################
## #
## #                                     Artifact upload to targets
## #
## ##################################################################################################################################

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

.PHONY: help
help: ## Display this help and exits.
	$(Q)echo ""
	$(Q)echo "  Version $$(git describe --always), Copyright (C) 2023-2026 AHL"
	$(Q)echo
	$(Q)echo "  Comes with ABSOLUTELY NO WARRANTY; for details see file LICENSE."
	$(Q)echo "  SPDX-License-Identifier: GPL-2.0-only"
	$(Q)echo
	$(Q)echo "$(TERM_UNDERLINE)Supported targets:$(TERM_NOUNDERLINE)"
	$(Q)echo
	$(Q)$(foreach b, $(sort $(notdir $(patsubst %_defconfig,%,$(wildcard $(DEFCONFIG_DIR)/*_defconfig)))), \
		printf "  	%-30s - Build configuration for %s\\n" $(b) $(b:_defconfig=); \
	)	

