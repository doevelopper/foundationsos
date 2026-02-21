################################################################################
#
# rpi5-security-init — First-boot TPM provisioning service
#
################################################################################

RPI5_SECURITY_INIT_VERSION = 0.1.0
RPI5_SECURITY_INIT_SITE    = $(BR2_EXTERNAL_FOUNDATIONSOS_PATH)/package/rpi5-security-init/src
RPI5_SECURITY_INIT_SITE_METHOD = local

define RPI5_SECURITY_INIT_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 755 $(@D)/security-init.sh \
		$(TARGET_DIR)/usr/local/bin/security-init.sh
	$(INSTALL) -D -m 644 $(@D)/security-init.service \
		$(TARGET_DIR)/etc/systemd/system/security-init.service
	ln -sf /etc/systemd/system/security-init.service \
		$(TARGET_DIR)/etc/systemd/system/basic.target.wants/security-init.service
endef

$(eval $(generic-package))
