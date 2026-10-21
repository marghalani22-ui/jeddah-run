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
# Tap the widget whose label contains $1; fall back to ($2% height, centre).
tap_label() {
  adb shell uiautomator dump /sdcard/ui.xml > /dev/null 2>&1
  adb shell cat /sdcard/ui.xml > diag/ui.xml 2>/dev/null
  B=$(python3 - "$1" <<'PY'
import re, sys
x = open('diag/ui.xml', encoding='utf-8', errors='ignore').read()
for m in re.finditer(r'<node [^>]*>', x):
    n = m.group(0)
    if sys.argv[1] in n:
        b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', n)
        if b:
            a, c, d, e = map(int, b.groups()); print((a + d) // 2, (c + e) // 2); break
PY
)
  if [ -n "$B" ]; then adb shell input tap $B; else adb shell input tap $((SW/2)) $((SH*$2/100)); fi
}
# first launch: onboarding
adb shell am start -W -n $PKG/.MainActivity > diag/start1.txt 2>&1
sleep 12; adb exec-out screencap -p > diag/ob-1.png
tap_label 'يلا نبدأ' 89;        sleep 3; adb exec-out screencap -p > diag/ob-2.png
tap_label 'التالي' 89;          sleep 3; adb exec-out screencap -p > diag/ob-3.png
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
