################################################################################
#
# rpi5-rauc-hawkbit — RAUC hawkBit OTA integration
#
################################################################################

RPI5_RAUC_HAWKBIT_VERSION = 1.0
RPI5_RAUC_HAWKBIT_SITE = $(BR2_EXTERNAL_FOUNDATIONSOS_PATH)/package/rpi5-rauc-hawkbit
RPI5_RAUC_HAWKBIT_SITE_METHOD = local
RPI5_RAUC_HAWKBIT_LICENSE = Apache-2.0
RPI5_RAUC_HAWKBIT_REDISTRIBUTE = NO

$(eval $(generic-package))
