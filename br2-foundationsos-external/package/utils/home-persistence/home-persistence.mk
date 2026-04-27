################################################################################
#
# home-persistence
#
################################################################################

HOME_PERSISTENCE_SYSTEMD_UNITS = \
	home.mount \
	root.mount
HOME_PERSISTENCE_SYSV_SCRIPTS = home-persistence-mount.sh
HOME_PERSISTENCE_SYSV_INIT_SCRIPTS = S30home-persistence-mount

define HOME_PERSISTENCE_INSTALL_INIT_SYSTEMD
	$(foreach unit,$(HOME_PERSISTENCE_SYSTEMD_UNITS), \
		$(INSTALL) -D -m 644 $(HOME_PERSISTENCE_PKGDIR)/$(unit) \
			$(TARGET_DIR)/usr/lib/systemd/system/$(unit)
	)
endef

define HOME_PERSISTENCE_INSTALL_INIT_SYSV
	$(foreach script,$(HOME_PERSISTENCE_SYSV_SCRIPTS), \
		$(INSTALL) -D -m 755 $(HOME_PERSISTENCE_PKGDIR)/$(script) \
			$(TARGET_DIR)/opt/$(script)
	)
	$(foreach init_script,$(HOME_PERSISTENCE_SYSV_INIT_SCRIPTS), \
		$(INSTALL) -D -m 755 $(HOME_PERSISTENCE_PKGDIR)/$(init_script) \
			$(TARGET_DIR)/etc/init.d/$(init_script)
	)
endef

$(eval $(generic-package))
