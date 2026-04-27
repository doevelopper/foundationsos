# Top-level Makefile for FoundationsOS

MAKE_HELPERS_DIRECTORY := helpers/

ROOT			       := $(dir $(abspath $(firstword $(MAKEFILE_LIST))))

include ${MAKE_HELPERS_DIRECTORY}define.mk
include ${MAKE_HELPERS_DIRECTORY}macros.mk
include ${MAKE_HELPERS_DIRECTORY}versioning.mk

DEVICE             ?= /dev/sdX
TFTP_PATH          ?= /srv/tftp

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

$(BLRT_PACKAGE_DIR)/buildroot-latest: 
	$(Q)$(call MESSAGE,"BLRT [Cloning latest buildroot from GitHub master] $@ ")
	$(Q)mkdir -pv $(BLRT_PACKAGE_DIR)
	$(Q)mkdir -pv $(BLRT_ARTIFACTS_DIR)
	$(Q)git clone --depth 1 https://github.com/buildroot/buildroot.git $@

$(BLRT_PACKAGE_DIR)/buildroot-master: 
	$(Q)$(call MESSAGE,"BLRT [Cloning buildroot $(BLRT_MASTER_BRANCH) from GitHub] $@ ")
	$(Q)mkdir -pv $(BLRT_PACKAGE_DIR)
	$(Q)mkdir -pv $(BLRT_ARTIFACTS_DIR)
	$(Q)git clone --depth 1 -b $(BLRT_MASTER_BRANCH) https://github.com/buildroot/buildroot.git $@

$(BLRT_PACKAGE_DIR)/buildroot-$(BLRT_VERSION): | $(BLRT_PACKAGE_DIR)/buildroot-$(BLRT_VERSION).tar.gz
	$(Q)$(CMD_PREFIX)$(call MESSAGE,"BLRT [Extracting buildroot-$(BLRT_VERSION)] $@ ")
	$(Q)cd $(BLRT_PACKAGE_DIR) && if [ ! -d $@ ]; then tar xf $(BLRT_PACKAGE_DIR)/buildroot-$(BLRT_VERSION).tar.gz; fi

# Resolve download dependency based on BLRT_MODE
ifeq ($(BLRT_MODE),latest)
    BLRT_DOWNLOAD_DEP := $(BLRT_PACKAGE_DIR)/buildroot-latest
else ifeq ($(BLRT_MODE),master)
    BLRT_DOWNLOAD_DEP := $(BLRT_PACKAGE_DIR)/buildroot-master
else
    BLRT_DOWNLOAD_DEP := $(BLRT_PACKAGE_DIR)/buildroot-$(BLRT_VERSION)
endif

$(BLRT_PACKAGE_DIR)/.buildroot-downloaded: | $(BLRT_DOWNLOAD_DEP)
	$(Q)$(call MESSAGE,"BLRT [Buildroot source ready: $(BLRT_VERSION_RESOLVED) mode]")
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
	$(Q)$(call MESSAGE,"[ Copying binaries to tftp server (TFTP_PATH=$(TFTP_PATH))]")
	$(Q)if [ -d "$(TFTP_PATH)" ]; then \
		rm -f $(TFTP_PATH)/*; \
		cp $(BLRT_OOSB)/$*-build-artifacts/images/u-boot.bin $(TFTP_PATH)/ 2>/dev/null || :; \
		cp --update=none $(BLRT_OOSB)/$*-build-artifacts/images/*.dtb $(TFTP_PATH)/ 2>/dev/null || :; \
		cp --update=none $(BLRT_OOSB)/$*-build-artifacts/images/*mage $(TFTP_PATH)/ 2>/dev/null || :; \
	else \
		$(call MESSAGE,"[  WARNING: TFTP_PATH=$(TFTP_PATH) not found, skipping TFTP deployment. Use 'make $*-compile TFTP_PATH=/path/to/tftp' to change]"); \
	fi
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

## Flash the SD card image to a target block device
## Usage: make <board>-flash DEVICE=/dev/sdX
$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-flash): %-flash:
	$(Q)$(call MESSAGE,"[  Flashing $* SD card image to $(DEVICE)]")
	@if [ "$(DEVICE)" = "/dev/sdX" ]; then \
		echo "Error: set DEVICE to your target block device, e.g. make $*-flash DEVICE=/dev/sdb"; \
		exit 1; \
	fi
	$(Q)$(BLRT_EXT)/scripts/flash.sh \
		--device $(DEVICE) \
		--image $(BLRT_ARTIFACTS_DIR)/$*/images/sdcard.img

## Build a signed RAUC update bundle for a specific board
## Usage: make <board>-rauc-bundle
$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-rauc-bundle): %-rauc-bundle:
	$(Q)$(call MESSAGE,"[  Building RAUC update bundle for $*]")
	$(Q)BOARD=$* \
		IMAGES_DIR=$(BLRT_ARTIFACTS_DIR)/$*/images \
		BUNDLE_DIR=$(BLRT_ARTIFACTS_DIR)/$* \
		$(BLRT_EXT)/scripts/build-rauc-bundle.sh
	$(Q)$(call MESSAGE,"[  RAUC bundle for $* ready.]")

.PHONY: help
help: ## Display this help and exits.
	$(Q)echo ""
	$(Q)echo "$(TERM_BOLD)  FoundationsOS — Secure Embedded Linux Build System$(TERM_RESET)"
	$(Q)echo "  Version $$(git describe --always --tags 2>/dev/null || echo dev), Copyright (C) 2023-2026 AHL"
	$(Q)echo "  Buildroot $(BLRT_VERSION)  |  Workspace: $(BLRT_OOSB)"
	$(Q)echo
	$(Q)echo "  Comes with ABSOLUTELY NO WARRANTY; for details see file LICENSE."
	$(Q)echo "  SPDX-License-Identifier: GPL-2.0-only"
	$(Q)echo
	$(Q)echo "$(TERM_UNDERLINE)Supported boards (BOARD suffix):$(TERM_NOUNDERLINE)"
	$(Q)echo
	$(Q)$(foreach b,$(SUPPORTED_TARGETS), \
		printf "    %-32s %s\n" "$(b)" "Board configuration: $(b)"; \
	)
	$(Q)echo
	$(Q)echo "$(TERM_UNDERLINE)Bootstrap (run once):$(TERM_NOUNDERLINE)"
	$(Q)printf "    %-32s %s\n" "<board>-configure"       "Download & configure Buildroot for <board>"
	$(Q)echo
	$(Q)echo "$(TERM_UNDERLINE)Build goals (replace <board> with a board name above):$(TERM_NOUNDERLINE)"
	$(Q)echo
	$(Q)printf "    %-32s %s\n" "<board>-compile"         "Compile full image and copy artifacts"
	$(Q)printf "    %-32s %s\n" "<board>-unit-test"       "Run unit tests (after compile)"
	$(Q)printf "    %-32s %s\n" "<board>-integration-test" "Run integration tests (after unit-test)"
	$(Q)printf "    %-32s %s\n" "<board>-artifacts-release" "Package board artifacts (after integration-test)"
	$(Q)echo
	$(Q)echo "$(TERM_UNDERLINE)Configuration goals:$(TERM_NOUNDERLINE)"
	$(Q)echo
	$(Q)printf "    %-32s %s\n" "<board>-menuconfig"      "Open Buildroot menuconfig for <board>"
	$(Q)printf "    %-32s %s\n" "<board>-savedefconfig"   "Save current config back to <board>_defconfig"
	$(Q)printf "    %-32s %s\n" "<board>-linux-menuconfig" "Open Linux kernel menuconfig & save defconfig"
	$(Q)printf "    %-32s %s\n" "<board>-linux-rebuild"   "Rebuild Linux kernel after config change"
	$(Q)printf "    %-32s %s\n" "<board>-uboot-menuconfig" "Open U-Boot menuconfig & save defconfig"
	$(Q)printf "    %-32s %s\n" "<board>-uboot-rebuild"   "Rebuild U-Boot after config change"
	$(Q)printf "    %-32s %s\n" "<board>-busybox-menuconfig" "Open BusyBox menuconfig & save config"
	$(Q)printf "    %-32s %s\n" "<board>-busybox-rebuild" "Rebuild BusyBox after config change"
	$(Q)echo
	$(Q)echo "$(TERM_UNDERLINE)Security / signing goals:$(TERM_NOUNDERLINE)"
	$(Q)echo
	$(Q)printf "    %-32s %s\n" "<board>-fit-sign"        "Sign FIT image for <board>"
	$(Q)printf "    %-32s %s\n" "<board>-rauc-bundle"     "Build a signed RAUC OTA update bundle"
	$(Q)echo
	$(Q)echo "$(TERM_UNDERLINE)Deployment goals:$(TERM_NOUNDERLINE)"
	$(Q)echo
	$(Q)printf "    %-32s %s\n" "<board>-flash DEVICE=..." "Flash SD card image to a block device"
	$(Q)echo
	$(Q)echo "$(TERM_UNDERLINE)Clean goals:$(TERM_NOUNDERLINE)"
	$(Q)echo
	$(Q)printf "    %-32s %s\n" "<board>-target-clean"    "Clean only the target staging area"
	$(Q)printf "    %-32s %s\n" "<board>-clean"           "Delete all files created by the build"
	$(Q)printf "    %-32s %s\n" "<board>-distclean"       "Delete all non-source files (incl. .config)"
	$(Q)printf "    %-32s %s\n" "<board>-realclean"       "Wipe the entire build-artifacts directory"
	$(Q)echo
	$(Q)echo "$(TERM_UNDERLINE)Variables:$(TERM_NOUNDERLINE)"
	$(Q)echo
	$(Q)printf "    %-32s %s\n" "BLRT_MODE=<mode>"       "Buildroot source mode: pinned (default), latest, or master"
	$(Q)printf "    %-32s %s\n" "BLRT_VERSION=<version>" "Specific Buildroot version when BLRT_MODE=pinned"
	$(Q)printf "    %-32s %s\n" "BLRT_MASTER_BRANCH=<branch>" "Git branch to clone when BLRT_MODE=master (default: master)"
	$(Q)printf "    %-32s %s\n" "DEVICE=/dev/sdX"         "Block device for <board>-flash (required)"
	$(Q)printf "    %-32s %s\n" "TFTP_PATH=/srv/tftp"     "TFTP server path for artifact deployment (default: /srv/tftp)"
	$(Q)printf "    %-32s %s\n" "V=1"                     "Enable verbose build output"
	$(Q)printf "    %-32s %s\n" "PARALLEL_JOBS=N"         "Override parallel job count (default: nproc+1)"
	$(Q)printf "    %-32s %s\n" "RAUC_KEY_FILE=..."       "Path to RAUC signing private key"
	$(Q)printf "    %-32s %s\n" "RAUC_CERT_FILE=..."      "Path to RAUC signing certificate"
	$(Q)printf "    %-32s %s\n" "FOUNDATIONSOS_VERSION=..." "Override OTA bundle version string"
	$(Q)echo
	$(Q)echo "$(TERM_UNDERLINE)Examples:$(TERM_NOUNDERLINE)"
	$(Q)echo
	$(Q)printf "    %s\n" "# Foundation3 (RPi3) - Use specific pinned version (default)"
	$(Q)printf "    %s\n" "make foundation3-configure"
	$(Q)printf "    %s\n" "make foundation3-compile"
	$(Q)printf "    %s\n" "make foundation3-compile TFTP_PATH=~/tftp"
	$(Q)echo
	$(Q)printf "    %s\n" "# Foundation5 (RPi5) - Use specific pinned version (default)"
	$(Q)printf "    %s\n" "make foundation5-configure"
	$(Q)printf "    %s\n" "make foundation5-compile"
	$(Q)printf "    %s\n" "make foundation5-rauc-bundle"
	$(Q)echo
	$(Q)printf "    %s\n" "# Use latest stable Buildroot release"
	$(Q)printf "    %s\n" "make BLRT_MODE=latest foundation5-configure"
	$(Q)printf "    %s\n" "make BLRT_MODE=latest foundation5-compile"
	$(Q)echo
	$(Q)printf "    %s\n" "# Use Buildroot master branch (development version)"
	$(Q)printf "    %s\n" "make BLRT_MODE=master foundation3-configure"
	$(Q)printf "    %s\n" "make BLRT_MODE=master foundation3-compile"
	$(Q)echo
	$(Q)printf "    %s\n" "# Use specific pinned version with custom BLRT_VERSION"
	$(Q)printf "    %s\n" "make BLRT_MODE=pinned BLRT_VERSION=2025.11 foundation5-configure"
	$(Q)echo
	$(Q)printf "    %s\n" "# Clone a specific git branch"
	$(Q)printf "    %s\n" "make BLRT_MODE=master BLRT_MASTER_BRANCH=next foundation5-configure"
	$(Q)echo
	$(Q)printf "    %s\n" "make raspberrypi3bp-rauc-bundle"
	$(Q)printf "    %s\n" "make raspberrypi5-linux-menuconfig"
	$(Q)echo
	$(Q)echo ".-----------------.--------------------.------------------.--------------------. "
	$(Q)echo "|  Adrien L. H    | Real-Time Embedded | /\"\ ASCII RIBBON | ACME's conspiracy: |"
	$(Q)echo "| +xx 000 000 000 | Software Architect | \ / CAMPAIGN     |  ___                |"
	$(Q)echo "| +xx 000 000 000 \`------------.-------:  X  AGAINST      |  \e/  There is no  |"
	$(Q)echo "| https://memyselandi_ad_exem/ | _/*\_ | / \ HTML MAIL    |   v   conspiracy.   |"
	$(Q)echo "'------------------------------^-------^------------------^---------------------'"
	$(Q)echo
