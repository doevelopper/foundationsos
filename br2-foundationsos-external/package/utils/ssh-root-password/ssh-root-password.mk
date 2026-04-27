################################################################################
#
# ssh-root-password
#
################################################################################

SSH_ROOT_PASSWORD_CONFIG_FILES = sshd_config

ifeq ($(BR2_PACKAGE_SSH_KEY_PERSISTENCE),y)
define SSH_ROOT_PASSWORD_INSTALL_CONFIG_ON_OPT
	$(foreach config_file,$(SSH_ROOT_PASSWORD_CONFIG_FILES), \
		$(INSTALL) -D -m 0644 $(SSH_ROOT_PASSWORD_PKGDIR)/$(config_file) \
			$(TARGET_DIR)/opt/ssh/$(config_file)
	)
endef
endif

define SSH_ROOT_PASSWORD_INSTALL_TARGET_CMDS
	$(foreach config_file,$(SSH_ROOT_PASSWORD_CONFIG_FILES), \
		$(INSTALL) -D -m 0644 $(SSH_ROOT_PASSWORD_PKGDIR)/$(config_file) \
			$(TARGET_DIR)/etc/ssh/$(config_file)
	)
	$(SSH_ROOT_PASSWORD_INSTALL_CONFIG_ON_OPT)
endef

$(eval $(generic-package))
