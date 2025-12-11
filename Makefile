TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = GGPoker

# Rootful for iPhone X + palera1n
THEOS_PACKAGE_SCHEME = rootful

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = IDFVSpoofer

IDFVSpoofer_FILES = Tweak.x
IDFVSpoofer_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
IDFVSpoofer_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
