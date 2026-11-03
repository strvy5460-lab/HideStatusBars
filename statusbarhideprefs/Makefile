TARGET := iphone:clang:latest:15.0
ARCHS = arm64

# Hapus baris berikut jika jailbreak Anda ROOTFUL
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = statusbarhideprefs

statusbarhideprefs_FILES = SBHRootListController.m
statusbarhideprefs_FRAMEWORKS = UIKit
statusbarhideprefs_PRIVATE_FRAMEWORKS = Preferences
statusbarhideprefs_INSTALL_PATH = /Library/PreferenceBundles
statusbarhideprefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
