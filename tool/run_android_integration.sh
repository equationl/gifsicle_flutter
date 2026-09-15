#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
reports="$root/tool/reports/android"
mkdir -p "$reports"
device=emulator-5554
adb -s "$device" wait-for-device
if [[ "${1:-}" == "16k" ]]; then
  adb -s "$device" shell getconf PAGE_SIZE | tr -d '\r' | grep -x 16384
fi
# Preserve device diagnostics even when Flutter exits before discovering tests.
adb -s "$device" logcat -c
adb -s "$device" logcat -v threadtime > "$reports/logcat.txt" 2>&1 &
log_pid=$!
trap 'kill "$log_pid" 2>/dev/null || true' EXIT
cd "$root/example"
for suite in gifsicle_integration_test demo_test; do
  flutter test "integration_test/$suite.dart" -d "$device" \
    --no-enable-impeller --reporter expanded --verbose \
    2>&1 | tee "$reports/$suite.log"
done
