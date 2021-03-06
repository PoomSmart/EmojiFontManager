TARGET = iphone:clang:latest:6.0
PACKAGE_VERSION = 1.0.0
ARCHS = armv7 arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = EmojiFontManager
EmojiFontManager_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk

BUNDLE_NAME = EFMPref
EFMPref_FILES = EFMPref.m
EFMPref_INSTALL_PATH = /Library/PreferenceBundles
EFMPref_CFLAGS = -fobjc-arc
EFMPref_LIBRARIES = EmojiLibrary
EFMPref_FRAMEWORKS = UIKit
EFMPref_EXTRA_FRAMEWORKS = Cephei
EFMPref_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/EFMPref.plist$(ECHO_END)
