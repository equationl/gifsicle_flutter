#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
reports="$root/tool/reports/android"
mkdir -p "$reports"
device=emulator-5554
adb -s "$device" wait-for-device
adb -s "$device" shell cat /proc/meminfo > "$reports/memory-before.txt"
if [[ "${1:-}" == "16k" ]]; then
  adb -s "$device" shell getconf PAGE_SIZE | tr -d '\r' | grep -x 16384
fi
# Preserve device diagnostics even when Flutter exits before discovering tests.
adb -s "$device" logcat -c
adb -s "$device" logcat -v threadtime > "$reports/logcat.txt" 2>&1 &
log_pid=$!
collect_diagnostics() {
  adb -s "$device" shell cat /proc/meminfo > "$reports/memory-after.txt" 2>&1 || true
  adb -s "$device" shell dumpsys meminfo > "$reports/dumpsys-meminfo.txt" 2>&1 || true
  adb -s "$device" shell dumpsys activity exit-info com.example.gifsicle_flutter > "$reports/app-exit-info.txt" 2>&1 || true
  kill "$log_pid" 2>/dev/null || true
}
trap collect_diagnostics EXIT
cd "$root/example"
for suite in gifsicle_integration_test demo_test; do
  flutter drive --driver=test_driver/integration_test.dart \
    --target="integration_test/$suite.dart" -d "$device" \
    --use-application-binary="$root/build/android-integration/$suite.apk" \
    --no-enable-impeller --verbose \
    2>&1 | tee "$reports/$suite.log"
done
