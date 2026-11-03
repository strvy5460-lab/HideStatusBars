TARGET := iphone:clang:latest:15.0
ARCHS = arm64

# Hapus baris berikut jika jailbreak Anda ROOTFUL
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = StatusBarHide
StatusBarHide_FILES = Tweak.xm
StatusBarHide_FRAMEWORKS = UIKit
StatusBarHide_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += statusbarhideprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
