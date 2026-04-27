################################################################################
#
# atop2
#
################################################################################

ATOP2_VERSION = 2.7.1
ATOP2_SITE = http://www.atoptool.nl/download
ATOP2_SOURCE = atop-$(ATOP2_VERSION).tar.gz
ATOP2_LICENSE = GPL-2.0+
ATOP2_LICENSE_FILES = COPYING
ATOP2_CPE_ID_VENDOR = atop_project
ATOP2_DEPENDENCIES = ncurses zlib

ATOP2_CFLAGS = $(TARGET_CFLAGS)

ifeq ($(BR2_TOOLCHAIN_HAS_GCC_BUG_85180),y)
ATOP2_CFLAGS += -O0
endif

define ATOP2_BUILD_CMDS
	$(MAKE) $(TARGET_CONFIGURE_OPTS) CFLAGS="$(ATOP2_CFLAGS)" \
		-C $(@D)
endef

define ATOP2_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/atop $(TARGET_DIR)/usr/bin/atop
endef

$(eval $(generic-package))
