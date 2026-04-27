################################################################################
#
# btop
#
################################################################################

BTOP_VERSION = 1b126f55e38de76a2cca796593ef1554828d61e6
BTOP_SITE = $(call github,aristocratos,btop,$(BTOP_VERSION))
BTOP_LICENSE = GPLv2
# no license file
# BTOP_LICENSE_FILES = module/netatop.c
# BTOP_DEPENDENCIES = zlib

# BTOP_MODULE_SUBDIRS = module

# define BTOP_BUILD_CMDS
# 	$(MAKE) $(TARGET_CONFIGURE_OPTS) CFLAGS="$(TARGET_CFLAGS)" \
# 		-C $(@D)/daemon
# endef

# define BTOP_INSTALL_TARGET_CMDS
# 	$(INSTALL) -D -m 0755 $(@D)/daemon/btoppd \
# 		$(TARGET_DIR)/usr/sbin/btoppd
# endef

# define BTOP_INSTALL_INIT_SYSV
# 	$(INSTALL) -D -m 0755 $(@D)/btopp.init \
# 		$(TARGET_DIR)/etc/init.d/S50netatop
# endef

# define BTOP_INSTALL_INIT_SYSTEMD
# 	$(INSTALL) -D -m 0644 $(@D)/netatop.service \
# 		$(TARGET_DIR)/usr/lib/systemd/system/netatop.service
# endef

# define BTOP_LINUX_CONFIG_FIXUPS
# 	$(call KCONFIG_ENABLE_OPT,CONFIG_NETFILTER)
# endef

$(eval $(kernel-module))
$(eval $(generic-package))
