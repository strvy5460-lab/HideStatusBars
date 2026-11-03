export THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0

INSTALL_TARGET_PROCESSES = Preferences

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = StatusBarHide
StatusBarHide_FILES = Tweak.x
StatusBarHide_CFLAGS = -fobjc-arc
StatusBarHide_FRAMEWORKS = UIKit Foundation

SUBPROJECTS += statusbarhideprefs

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
