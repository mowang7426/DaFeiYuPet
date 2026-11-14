DEBUG = 0
FINALPACKAGE = 1

ARCHS = arm64 arm64e

# Share the SDK and deployment targets with the PreferenceBundle.
include AxsDaFeiYuPetBuild.mk
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AxsDaFeiYuPet
AxsDaFeiYuPet_FILES = $(wildcard Hooks/*.xm Sources/*.m)
AxsDaFeiYuPet_CFLAGS = -fobjc-arc -I./Headers -I./Sources
AxsDaFeiYuPet_FRAMEWORKS = UIKit Foundation CoreFoundation QuartzCore
AxsDaFeiYuPet_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += AxsDaFeiYuPetPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
