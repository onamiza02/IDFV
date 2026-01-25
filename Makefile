TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = GGPoker AppStore_GGPCOM

# Rootless support (Dopamine/Palera1n)
THEOS_PACKAGE_SCHEME = rootless

ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = IDFVSpoofer

IDFVSpoofer_FILES = Tweak.x
IDFVSpoofer_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable
IDFVSpoofer_FRAMEWORKS = UIKit Foundation Security AdSupport
IDFVSpoofer_PRIVATE_FRAMEWORKS =
IDFVSpoofer_LDFLAGS = -lz

include $(THEOS_MAKE_PATH)/tweak.mk

# Settings UI Bundle
SUBPROJECTS += idfvspooferprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
