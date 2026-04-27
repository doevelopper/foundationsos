################################################################################
#
# hello-cmake
#
################################################################################

HELLO_CMAKE_VERSION = 1.0
HELLO_CMAKE_SOURCE = hello-cmake-$(HELLO_CMAKE_VERSION).tar.bz2
HELLO_CMAKE_SITE = https://www.blaess.fr/christophe/yocto-lab/files
HELLO_CMAKE_LICENSE = GPL-2.0

$(eval $(cmake-package))
