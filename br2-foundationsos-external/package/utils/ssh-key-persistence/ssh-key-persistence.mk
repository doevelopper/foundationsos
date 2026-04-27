################################################################################
#
# ssh-key-persistence
#
################################################################################

SSH_KEY_PERSISTENCE_COMMON_SCRIPTS = ssh-key-persistence-config.sh
SSH_KEY_PERSISTENCE_SYSTEMD_UNITS = \
	etc-ssh.mount \
	ssh-key-persistence.service
SSH_KEY_PERSISTENCE_SYSV_SCRIPTS = ssh-key-persistence-mount.sh
SSH_KEY_PERSISTENCE_SYSV_INIT_SCRIPTS = S49ssh-key-persistence

define SSH_KEY_PERSISTENCE_INSTALL_TARGET_CMDS
	$(foreach script,$(SSH_KEY_PERSISTENCE_COMMON_SCRIPTS), \
		$(INSTALL) -D -m 0755 $(SSH_KEY_PERSISTENCE_PKGDIR)/$(script) \
			$(TARGET_DIR)/opt/$(script)
	)
endef

define SSH_KEY_PERSISTENCE_INSTALL_INIT_SYSTEMD
	$(foreach unit,$(SSH_KEY_PERSISTENCE_SYSTEMD_UNITS), \
		$(INSTALL) -D -m 644 $(SSH_KEY_PERSISTENCE_PKGDIR)/$(unit) \
			$(TARGET_DIR)/usr/lib/systemd/system/$(unit)
	)
endef

define SSH_KEY_PERSISTENCE_INSTALL_INIT_SYSV
	$(foreach script,$(SSH_KEY_PERSISTENCE_SYSV_SCRIPTS), \
		$(INSTALL) -D -m 755 $(SSH_KEY_PERSISTENCE_PKGDIR)/$(script) \
			$(TARGET_DIR)/opt/$(script)
	)
	$(foreach init_script,$(SSH_KEY_PERSISTENCE_SYSV_INIT_SCRIPTS), \
		$(INSTALL) -D -m 755 $(SSH_KEY_PERSISTENCE_PKGDIR)/$(init_script) \
			$(TARGET_DIR)/etc/init.d/$(init_script)
	)
endef

$(eval $(generic-package))
