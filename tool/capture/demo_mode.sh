#!/usr/bin/env bash
# SystemUI 데모 모드: 상태 표시줄을 9:41·와이파이·배터리만 남긴다. `demo_mode.sh off` 로 해제.
ADB=${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}
b() { "$ADB" shell am broadcast -a com.android.systemui.demo "$@" >/dev/null; }
if [ "$1" = off ]; then
  b -e command exit
  "$ADB" shell settings put global sysui_demo_allowed 0
  exit 0
fi
"$ADB" shell settings put global sysui_demo_allowed 1
b -e command enter
b -e command clock -e hhmm 0941
b -e command network -e wifi show -e level 4 -e mobile hide
b -e command battery -e level 100 -e plugged false
b -e command notifications -e visible false
