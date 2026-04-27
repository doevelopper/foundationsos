################################################################################
#
# cucumber-cpp
#
################################################################################

CUCUMBER_CPP_VERSION = 2f7d9ad519290a8b4a6ee6845af4480dd9ec2b7f
CUCUMBER_CPP_SITE = $(call github,cucumber,cucumber-cpp,$(CUCUMBER_CPP_VERSION))
CUCUMBER_CPP_INSTALL_STAGING = YES
CUCUMBER_CPP_LICENSE = BSD-3-Clause
CUCUMBER_CPP_LICENSE_FILES = COPYING.txt

# Force Release otherwise libraries will be suffixed by _debug which will raise
# unexpected build failures with packages that use gflags (e.g. rocksdb)
CUCUMBER_CPP_CONF_OPTS = \
	-DCMAKE_BUILD_TYPE=Release \
	-DCUKE_ENABLE_EXAMPLES=OFF \
	-DCUKE_ENABLE_QT=OFF \
	-DCUKE_TESTS_E2E=OFF \
	-DCUKE_ENABLE_SANITIZER=OFF \
	-DCUKE_ENABLE_BOOST_TEST=OFF
#-DCMAKE_INSTALL_PREFIX=${prefix}

ifeq ($(BR2_TOOLCHAIN_HAS_THREADS),)
CUCUMBER_CPP_CONF_OPTS += -DBUILD_gflags_LIB=OFF \
	-DCMAKE_CXX_FLAGS="$(TARGET_CXXFLAGS) -DNO_THREADS"
endif

$(eval $(cmake-package))
