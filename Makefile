TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = GGPoker

THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = IDFVSpoofer

IDFVSpoofer_FILES = Tweak.x
IDFVSpoofer_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
IDFVSpoofer_FRAMEWORKS = UIKit Foundation Security

include $(THEOS_MAKE_PATH)/tweak.mk
