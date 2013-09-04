TWEAK_NAME = PullToDisableAlarms
PullToDisableAlarms_OBJC_FILES = Tweak.xm
PullToDisableAlarms_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS = pulltodisablealarmssettings
include $(THEOS_MAKE_PATH)/aggregate.mk

