TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = GGPoker

# Rootless support (Dopamine/Palera1n)
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = IDFVSpoofer

IDFVSpoofer_FILES = Tweak.x
IDFVSpoofer_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
IDFVSpoofer_FRAMEWORKS = UIKit Foundation Security

include $(THEOS_MAKE_PATH)/tweak.mk

# Settings bundle disabled for now (GitHub Actions doesn't have Preferences.framework)
# Build locally with: make package SUBPROJECTS=idfvspooferprefs
# SUBPROJECTS += idfvspooferprefs
# include $(THEOS_MAKE_PATH)/aggregate.mk
