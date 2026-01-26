ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = IDFVSpooferPrefs

IDFVSpooferPrefs_FILES = IDFVRootListController.m
IDFVSpooferPrefs_FRAMEWORKS = UIKit
IDFVSpooferPrefs_CFLAGS = -fobjc-arc
IDFVSpooferPrefs_LDFLAGS = -undefined dynamic_lookup
IDFVSpooferPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
