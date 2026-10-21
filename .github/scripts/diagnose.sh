#!/bin/bash
# Installs the APK on an emulator, launches it, and saves screenshots + logs to diag/.
set -x
PKG=sa.jeddahrun.jeddah_run
mkdir -p diag
adb install -r jeddah-run.apk > diag/install.txt 2>&1
adb shell pm grant $PKG android.permission.POST_NOTIFICATIONS
adb shell pm grant $PKG android.permission.ACCESS_FINE_LOCATION
adb shell pm grant $PKG android.permission.ACCESS_COARSE_LOCATION
adb logcat -c
W=$(adb shell wm size | grep -oE "[0-9]+x[0-9]+" | tail -1); SW=${W%x*}; SH=${W#*x}
# Onboarding buttons sit at fixed heights (percent of screen), centred.
tap_label() { adb shell input tap $((SW/2)) $((SH*$2/100)); }
# first launch: onboarding
adb shell am start -W -n $PKG/.MainActivity > diag/start1.txt 2>&1
sleep 15; adb exec-out screencap -p > diag/ob-1.png
tap_label 'يلا نبدأ' 92;        sleep 4; adb exec-out screencap -p > diag/ob-2.png
tap_label 'التالي' 92;          sleep 4; adb exec-out screencap -p > diag/ob-3.png
tap_label 'اسمح بالموقع' 83;    sleep 4; adb exec-out screencap -p > diag/ob-4.png
tap_label 'فعّل التذكيرات' 83;  sleep 5; adb exec-out screencap -p > diag/1-home.png
adb shell dumpsys meminfo $PKG | head -40 > diag/meminfo.txt
adb logcat -d -v time > diag/logcat-first.txt
# relaunch: should go straight to the map now
adb shell am force-stop $PKG
adb logcat -c
adb shell am start -W -n $PKG/.MainActivity > diag/start2.txt 2>&1
sleep 20; adb exec-out screencap -p > diag/3-granted-20s.png
# bottom-nav tabs sit at y≈95% of the screen; RTL order: map, log, shop, profile from the right
Y=$((SH*95/100))
for t in 2 3 4 5; do X=$((SW - SW*(2*t-1)/10)); adb shell input tap $X $Y; sleep 3; adb exec-out screencap -p > diag/tab-$t.png; done
adb logcat -d -v time > diag/logcat-second.txt
grep -E "FATAL|AndroidRuntime|flutter|E/|Choreographer|ANR" diag/logcat-first.txt diag/logcat-second.txt | head -300 > diag/important.txt
true
