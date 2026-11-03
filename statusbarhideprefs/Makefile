TARGET = iphone:clang:latest:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = statusbarhideprefs
statusbarhideprefs_FILES = SBHRootListController.m SBHAppListController.m
statusbarhideprefs_INSTALL_PATH = /Library/PreferenceBundles
statusbarhideprefs_FRAMEWORKS = UIKit
statusbarhideprefs_PRIVATE_FRAMEWORKS = Preferences
statusbarhideprefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
