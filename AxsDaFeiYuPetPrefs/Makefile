include ../AxsDaFeiYuPetBuild.mk
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = AxsDaFeiYuPetPrefs
AxsDaFeiYuPetPrefs_FILES = $(wildcard *.m)
AxsDaFeiYuPetPrefs_CFLAGS = -fobjc-arc -I../Sources
AxsDaFeiYuPetPrefs_FRAMEWORKS = UIKit Foundation CoreFoundation Security
AxsDaFeiYuPetPrefs_PRIVATE_FRAMEWORKS = Preferences
AxsDaFeiYuPetPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
