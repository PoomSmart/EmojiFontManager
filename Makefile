TARGET = iphone:clang:11.2:6.0
PACKAGE_VERSION = 0.0.5e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = EmojiFontManager
EmojiFontManager_FILES = Tweak.xm
EmojiFontManager_EXTRA_FRAMEWORKS = Cephei

include $(THEOS_MAKE_PATH)/tweak.mk

BUNDLE_NAME = EFMPref
EFMPref_FILES = EFMPref.m
EFMPref_INSTALL_PATH = /Library/PreferenceBundles
EFMPref_LIBRARIES = EmojiLibrary
EFMPref_EXTRA_FRAMEWORKS = Cephei CepheiPrefs
EFMPref_PRIVATE_FRAMEWORKS = Preferences
EFMPref_FRAMEWORKS = CoreGraphics UIKit

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/EFMPref.plist$(ECHO_END)
	$(ECHO_NOTHING)find $(THEOS_STAGING_DIR) -name .DS_Store | xargs rm -rf$(ECHO_END)
