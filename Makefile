
TWEAK_NAME = PullToDisableAlarms
PullToDisableAlarms_OBJC_FILES = Tweak.xm
PullToDisableAlarms_FRAMEWORKS = UIKit

include framework/makefiles/common.mk
include framework/makefiles/tweak.mk

SUBPROJECTS = pulltodisablealarmssettings
include framework/makefiles/aggregate.mk


