################################################################################
#
# netatop
#
################################################################################

NETATOP_VERSION = 3.1
NETATOP_SITE = http://www.atoptool.nl/download
NETATOP_LICENSE = GPLv2
# no license file
NETATOP_LICENSE_FILES = module/netatop.c
NETATOP_DEPENDENCIES = zlib

NETATOP_MODULE_SUBDIRS = module

define NETATOP_BUILD_CMDS
	$(MAKE) $(TARGET_CONFIGURE_OPTS) CFLAGS="$(TARGET_CFLAGS)" \
		-C $(@D)/daemon
endef

define NETATOP_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/daemon/netatopd \
		$(TARGET_DIR)/usr/sbin/netatopd
endef

define NETATOP_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0755 $(@D)/netatop.init \
		$(TARGET_DIR)/etc/init.d/S50netatop
endef

define NETATOP_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 0644 $(@D)/netatop.service \
		$(TARGET_DIR)/usr/lib/systemd/system/netatop.service
endef

define NETATOP_LINUX_CONFIG_FIXUPS
	$(call KCONFIG_ENABLE_OPT,CONFIG_NETFILTER)
endef

$(eval $(kernel-module))
$(eval $(generic-package))
