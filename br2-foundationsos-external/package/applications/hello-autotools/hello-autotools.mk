################################################################################
#
# hello-autotools
#
################################################################################

HELLO_AUTOTOOLS_VERSION = 1.0
HELLO_AUTOTOOLS_SOURCE = hello-autotools-$(HELLO_AUTOTOOLS_VERSION).tar.bz2
HELLO_AUTOTOOLS_SITE = https://www.blaess.fr/christophe/yocto-lab/files
HELLO_AUTOTOOLS_AUTORECONF = YES
HELLO_AUTOTOOLS_LICENSE = GPL-2.0

$(eval $(autotools-package))
