################################################################################
#
# persist-partition
#
################################################################################

PERSIST_PARTITION_SYSTEMD_UNITS = mnt-persist.mount

define PERSIST_PARTITION_INSTALL_INIT_SYSTEMD
	$(foreach unit,$(PERSIST_PARTITION_SYSTEMD_UNITS), \
		$(INSTALL) -D -m 644 $(PERSIST_PARTITION_PKGDIR)/$(unit) \
			$(TARGET_DIR)/usr/lib/systemd/system/$(unit)
	)
endef

define PERSIST_PARTITION_INSTALL_INIT_SYSV
	mkdir -p $(TARGET_DIR)/mnt/persist
	$(SED) '/^\/dev\/mmcblk0p4/d' $(TARGET_DIR)/etc/fstab
	echo '/dev/mmcblk0p4 /mnt/persist ext4 defaults 0 0' >> $(TARGET_DIR)/etc/fstab
endef

$(eval $(generic-package))
