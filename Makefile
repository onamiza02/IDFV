TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = GGPoker

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = IDFVSpoofer

IDFVSpoofer_FILES = Tweak.x
IDFVSpoofer_CFLAGS = -fno-objc-arc -Wno-deprecated-declarations
IDFVSpoofer_FRAMEWORKS = UIKit Foundation Security

include $(THEOS_MAKE_PATH)/tweak.mk
