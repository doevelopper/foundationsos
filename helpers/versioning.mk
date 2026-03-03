# Get the current username
USERNAME 							:= $(subst ' ','_',$(subst .,'_',$(shell git config user.name)))

# Get the current Git branch
GIT_BRANCH 							:= $(shell git rev-parse --abbrev-ref HEAD)

# Get the latest Git tag
GIT_DESCRIBE_OUTPUT 				:= $(shell git describe --tags --abbrev=0 2>/dev/null)

ifneq ($(GIT_DESCRIBE_OUTPUT),)
	FULLTAG 						:= $(GIT_DESCRIBE_OUTPUT)
else
	FULLTAG 						:= WHATEVER_$(SW_PN)_program_0.0.0
endif

# Branch-specific version handling
ifeq ($(GIT_BRANCH),main)
    VERSION_PREFIX 					=
    VERSION_POSTFIX 				=
else ifeq ($(GIT_BRANCH),develop)
    VERSION_PREFIX 					= dev-
    VERSION_POSTFIX 				= -SNAPSHOOT
else ifneq ($(filter feature/%,$(GIT_BRANCH)),)
    VERSION_PREFIX 					= feature-$(subst feature/,,$(GIT_BRANCH))-
    VERSION_POSTFIX 				= -TUMBLEWEED
else ifneq ($(filter bugfix/%,$(GIT_BRANCH)),)
    VERSION_PREFIX 					= bugfix-$(subst bugfix/,,$(GIT_BRANCH))-
    VERSION_POSTFIX 				= -TUMBLEWEED
else ifneq ($(filter defect/%,$(GIT_BRANCH)),)
    VERSION_PREFIX 					= defect-$(subst defect/,,$(GIT_BRANCH))-
    VERSION_POSTFIX 				= -TUMBLEWEED
endif

COMMIT            					:= $(shell git rev-parse --short HEAD)
COMMIT_DATE       					:= $(shell git log -1 --format=%cd --date=format:"%Y%m%d")

# Extract platform, program name, major, minor, and patch versions from the release name
HPS_VERSION       					:= $(lastword $(subst _, ,$(FULLTAG)))
PLATFORM          					:= $(firstword $(subst _, ,$(FULLTAG)))
PROGRAM_NAME      					:= $(word 2,$(subst _, ,$(FULLTAG)))

HPS_MAJOR_TAG     					:= $(word 1,$(subst ., ,$(word 3,$(subst _, ,$(FULLTAG)))))
HPS_MINOR_TAG     					:= $(word 2,$(subst ., ,$(word 3,$(subst _, ,$(FULLTAG)))))
HPS_PATCH_TAG     					:= $(word 3,$(subst ., ,$(word 3,$(subst _, ,$(FULLTAG)))))

# Increment major, minor, and patch versions
NEW_MAJOR_VERSION 					?= $(shell expr $(HPS_MAJOR_TAG) + 1)
NEW_MINOR_VERSION 					?= $(shell expr $(HPS_MINOR_TAG) + 1)
NEW_PATCH_VERSION 					?= $(shell expr $(HPS_PATCH_TAG) + 1)

# LAST_TAG=$(git describe --abbrev=0 --exclude='*-rc*')
# COMMITS=$(git rev-list --count "$(git describe --abbrev=0 --exclude='*-rc*')..HEAD")
# REVISION=$(git rev-parse --short=8 HEAD || echo unknown)

define do_release
	$(Q)echo "git checkout -b release/${1} develop"
	$(Q)echo "git checkout main"
	$(Q)echo " git merge --no-ff release/${1}"
	$(Q)echo " git tag -a ${1}"
	$(Q)echo " git checkout develop"
	$(Q)echo " git merge --no-ff release/${1}"
	$(Q)echo " git branch -d release/${1}"
endef


$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-bump-major): %-bump-major:
	$(Q)$(call MESSAGE,"[  Bumping major software version of $*]")
	$(eval NEW_MAJOR_VERSION ?= $(NEW_MAJOR_VERSION_ARG))
	$(eval NEW_MINOR_VERSION = 0)
	$(eval NEW_PATCH_VERSION = 0)
	$(Q)$(call MESSAGE,"    [Applying release tag $(NEW_MAJOR_VERSION).$(NEW_MINOR_VERSION).$(NEW_PATCH_VERSION)]")
#	$(Q)echo "git tag $(NEW_MAJOR_VERSION).$(NEW_MINOR_VERSION).$(NEW_PATCH_VERSION)"
#	$(Q)echo "git push --tags"
	$(Q)$(call do_release,$(NEW_MAJOR_VERSION).$(NEW_MINOR_VERSION).$(NEW_PATCH_VERSION))

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-bump-minor): %-bump-minor:
	$(Q)$(call MESSAGE,"[  Bumping minor software version of $*]")
	$(eval NEW_MINOR_VERSION ?= $(NEW_MINOR_VERSION_ARG))
	$(eval NEW_PATCH_VERSION = 0)
	$(Q)$(call MESSAGE,"    [Applying release tag $(HPS_MAJOR_TAG).$(NEW_MINOR_VERSION).$(NEW_PATCH_VERSION)]")
#	 $(Q)echo "git tag $(HPS_MAJOR_TAG).$(NEW_MINOR_VERSION).$(NEW_PATCH_VERSION)"
#	 $(Q)echo "git push --tags"
	$(Q)$(call do_release,$(HPS_MAJOR_TAG).$(NEW_MINOR_VERSION).$(NEW_PATCH_VERSION))

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-bump-patch): %-bump-patch:
	$(Q)$(call MESSAGE,"[  Bumping minor software version of $*]")
	$(eval NEW_PATCH_VERSION ?= $(NEW_PATCH_VERSION_ARG))
	$(Q)$(call MESSAGE,"    [Applying release tag $(HPS_MAJOR_TAG).$(HPS_MINOR_TAG).$(NEW_PATCH_VERSION)]")
#	$(Q)echo "git tag $(HPS_MAJOR_TAG).$(HPS_MINOR_TAG).$(NEW_PATCH_VERSION)"
#	$(Q)echo "git push --tags"
#	$(Q)echo "git checkout -b release/$(HPS_MAJOR_TAG).$(HPS_MINOR_TAG).$(NEW_PATCH_VERSION) develop"
	$(Q)$(call do_release,$(HPS_MAJOR_TAG).$(HPS_MINOR_TAG).$(NEW_PATCH_VERSION))


$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-release): %-release: %-bump-patch
	$(Q)$(call MESSAGE,"[  $* 's new release creation]")


show-versions:
	$(Q)$(call MESSAGE,"Platform: $(PLATFORM)")
	$(Q)$(call MESSAGE,"Program Name: $(PROGRAM_NAME)")
	$(Q)$(call MESSAGE,"Current Version: $(HPS_MAJOR_TAG).$(HPS_MINOR_TAG).$(HPS_PATCH_TAG)")
	$(Q)$(call MESSAGE,"New Major Version: $(NEW_MAJOR_VERSION).0.0")
	$(Q)$(call MESSAGE,"New Minor Version: $(HPS_MAJOR_TAG).$(NEW_MINOR_VERSION).0")
	$(Q)$(call MESSAGE,"New Patch Version: $(HPS_MAJOR_TAG).$(HPS_MINOR_TAG).$(NEW_PATCH_VERSION)")
	$(Q)$(call MESSAGE,"Current Branch: $(GIT_BRANCH)")
	$(Q)$(call MESSAGE,"Version Prefix: $(VERSION_PREFIX)")
	$(Q)$(call MESSAGE,"Full Versions:  $(VERSION_PREFIX)$(HPS_MAJOR_TAG).$(HPS_MINOR_TAG).$(NEW_PATCH_VERSION)$(VERSION_POSTFIX)")
	$(Q)$(eval CURRENT_VERSION_TAG := $(HPS_MAJOR_TAG).$(HPS_MINOR_TAG).$(HPS_PATCH_TAG))
	$(Q)$(eval NEW_VERSION_TAG := $(HPS_MAJOR_TAG).$(HPS_MINOR_TAG).$(NEW_PATCH_VERSION))
	$(Q)export CURRENT_VERSION_TAG NEW_VERSION_TAG PLATFORM PROGRAM_NAME HPS_MAJOR_TAG HPS_MINOR_TAG NEW_PATCH_VERSION SW_PN SW_PN

