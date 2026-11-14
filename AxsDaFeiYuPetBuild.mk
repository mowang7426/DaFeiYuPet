DEBUG ?= 0
FINALPACKAGE ?= 1
ARCHS = arm64 arm64e

# SDK pinned once, deployment floor shared by tweak and preferences.
TARGET = iphone:clang:16.5:15.0
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
ADDITIONAL_CFLAGS += -DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1
endif
