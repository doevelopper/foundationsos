#
# Copyright (c) 2022-2024, ACME AHL Limited and Contributors. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Report an error if the eval make function is not available.
$(eval eval_available := T)
ifneq (${eval_available},T)
    $(error This makefile only works with a Make program that supports $$(eval))
endif

# Time steps
define step_time
    printf "%s:%-5.5s:%-20.20s: %s\n"               	\
           "$$(date +%s.%N)" "$(1)" "$(2)" "$(3)"      	\
           >>"$(BUILD_DIR)/build-time.log"
endef

word-dot                = $(word $2,$(subst ., ,$1))
UC                      = $(shell echo '$1' | tr '[:lower:]' '[:upper:]')

# Convenience function for adding build definitions
# $(eval $(call add_define,FOO)) will have:
# -DFOO if $(FOO) is empty; -DFOO=$(FOO) otherwise
define add_define
    DEFINES				+=	-D$(1)$(if $(value $(1)),=$(value $(1)),)
endef


# A user defined function to recursively search for a filename below a directory
#    $1 is the directory root of the recursive search (blank for current directory).
#    $2 is the file name to search for.
define rwildcard
	$(strip $(foreach d,$(wildcard ${1}*),$(call rwildcard,${d}/,${2}) $(filter $(subst *,%,%${2}),${d})))
endef

# Convenience function for addding multiple build definitions
# $(eval $(call add_defines,FOO BOO))
define add_defines
    $(foreach def,$1,$(eval $(call add_define,$(def))))
endef

# Convenience function for adding build definitions
# $(eval $(call add_define_val,FOO,BAR)) will have:
# -DFOO=BAR
define add_define_val
    DEFINES			+=	-D$(1)=$(2)
endef

# Convenience function for verifying option has a boolean value
# $(eval $(call assert_boolean,FOO)) will assert FOO is 0 or 1
define assert_boolean
    $(if $(filter-out 0 1,$($1)),$(error $1 must be boolean))
endef

# Convenience function for verifying options have boolean values
# $(eval $(call assert_booleans,FOO BOO)) will assert FOO and BOO for 0 or 1 values
define assert_booleans
    $(foreach bool,$1,$(eval $(call assert_boolean,$(bool))))
endef

# GZIP
define GZIP_RULE
$(1): $(2)
	$(ECHO) "  GZIP    $$@"
	$(Q)gzip -n -f -9 $$< --stdout > $$@
endef

GZIP_SUFFIX := .gz

# ENCRYPT_FW invokes enctool to encrypt firmware binary
#   $(1) = input firmware binary
#   $(2) = output encrypted firmware binary
define ENCRYPT_FW
$(2): $(1) enctool
	$$(ECHO) "  ENC     $$<"
	$$(Q)$$(ENCTOOL) $$(ENC_ARGS) -i $$< -o $$@
endef

# ${1} is the file to be copied.
# ${2} is the destination file name.
define SHELL_COPY
	${Q}cp -f  "${1}"  "${2}"
endef

# ${1} is the directory to be copied.
# ${2} is the destination directory path.
define SHELL_COPY_TREE
	${Q}cp -rf  "${1}"  "${2}"
endef

# ${1} is the file to be deleted.
define SHELL_DELETE
	-${Q}rm -f  "${1}"
endef

# ${1} is a space delimited list of files to be deleted.
# Note that we do not quote ${1}, as multiple parameters may be passed.
define SHELL_DELETE_ALL
	-${Q}rm -rf  ${1}
endef

# ${1} is the directory to be generated.
# ${2} is optional, and allows a prerequisite to be specified.
# Do nothing if $1 == $2, to ignore self dependencies.
define MAKE_PREREQ_DIR
    ifneq (${1},${2})

		${1} : ${2}
		${Q}mkdir -p  "${1}"

    endif
endef

define SHELL_REMOVE_DIR
	-${Q}rm -rf  "${1}"
endef


ifndef SHELL_COPY
	$(error "SHELL_COPY not defined for build environment.")
endif
ifndef SHELL_COPY_TREE
	$(error "SHELL_COPY_TREE not defined for build environment.")
endif
ifndef SHELL_DELETE_ALL
	$(error "SHELL_DELETE_ALL not defined for build environment.")
endif
ifndef SHELL_DELETE
	$(error "SHELL_DELETE not defined for build environment.")
endif
ifndef MAKE_PREREQ_DIR
	$(error "MAKE_PREREQ_DIR not defined for build environment.")
endif
ifndef SHELL_REMOVE_DIR
	$(error "SHELL_REMOVE_DIR not defined for build environment.")
endif


# Process Debug flag
$(eval $(call add_define,DEBUG))
ifneq (${DEBUG}, 0)
        BUILD_TYPE	:=	debug
        TF_CFLAGS	+= 	-g

        ifneq ($(findstring clang,$(notdir $(CC))),)
            ASFLAGS		+= 	-g
        else
            ASFLAGS		+= 	-g -Wa,--gdwarf-2
        endif

        # Use LOG_LEVEL_INFO by default for debug builds
        LOG_LEVEL	:=	40
else
        BUILD_TYPE	:=	release
        # Use LOG_LEVEL_NOTICE by default for release builds
        LOG_LEVEL	:=	20
endif

# Default build string (git branch and commit)
ifeq (${BUILD_STRING},)
    BUILD_STRING         :=  $(shell git describe --always --dirty --tags 2> /dev/null)
endif
VERSION_STRING           :=  v${VERSION_MAJOR}.${VERSION_MINOR}(${BUILD_TYPE}):${BUILD_STRING}

# Set a variable or error out if it was previously set to a different value
# The reason message (3rd parameter) is optional
# Example:
# $(call force,CFG_FOO,foo,required by CFG_BAR)
define force
    $(eval $(call _force,$(1),$(2),$(3)))
endef

define _force
    ifdef $(1)
        ifneq ($($(1)),$(2))
            ifneq (,$(3))
                _reason := $$(_empty) [$(3)]
            endif
            $$(error $(1) is set to '$($(1))' (from $(origin $(1))) but its value must be '$(2)'$$(_reason))
        endif
    endif
    $(1) := $(2)
endef


define GENERATE_CHECKSUM_AND_SIGNATURE
$(Q)$(call MESSAGE,"[ Generating $* artifacts checksum, signatures...]")
$(Q)$(eval FILES := $(wildcard $(BLRT_OOSB)/$*-build-artifacts/images/*))
$(Q)$(foreach FILE,$(FILES),$(Q)sha256sum $(FILE) > $(FILE).sha256;)

$(Q)$(foreach EXT,gz bz2 zip xz,\
    $(Q)tar caf $(BLRT_OOSB)/$*-build-artifacts/images/$*.$(EXT) -C $(BLRT_OOSB)/$*-build-artifacts/images rootfs.ext2 Image;\
    $(Q)gpg --detach-sign --armor $(BLRT_OOSB)/$*-build-artifacts/images/$*.$(EXT);\
)

$(Q)du -sch --time $(BLRT_OOSB)/$*-build-artifacts/images/*
endef