export THEOS ?= $(HOME)/theos

TARGET := iphone:clang:latest:7.0
ARCHS := armv7 arm64
INSTALL_TARGET_PROCESSES = Podcasts itunesstored

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PodcastsFix7

PodcastsFix7_FILES = Tweak.xm
PodcastsFix7_CFLAGS = -fobjc-arc

include $(THEOS)/makefiles/tweak.mk
