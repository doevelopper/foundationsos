################################################################################
#
# hello-makefile
#
################################################################################

HELLO_MAKEFILE_VERSION = 1.0
HELLO_MAKEFILE_SOURCE = hello-makefile-$(HELLO_MAKEFILE_VERSION).tar.bz2
HELLO_MAKEFILE_SITE = https://www.blaess.fr/christophe/yocto-lab/files
HELLO_MAKEFILE_LICENSE = GPL-2.0


define HELLO_MAKEFILE_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) CC="$(TARGET_CC)"
endef

define HELLO_MAKEFILE_INSTALL_TARGET_CMDS
        $(TARGET_MAKE_ENV) $(MAKE) -C $(@D) install DESTDIR=$(TARGET_DIR)/usr/bin
endef



$(eval $(generic-package))
