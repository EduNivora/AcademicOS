#!/usr/bin/env bash
set -euo pipefail

echo "Waiting for Android emulator..."
timeout 120 adb wait-for-device

boot_ready=0
for probe in $(seq 1 60); do
  boot_state="$(timeout 5 adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
  if [[ "$boot_state" == "1" ]]; then
    boot_ready=1
    break
  fi
  sleep 2
done
if [[ "$boot_ready" -ne 1 ]]; then
  echo "::error::Android emulator did not finish booting."
  timeout 15 adb logcat -d -t 1200 || true
  exit 1
fi

package_ready=0
for probe in $(seq 1 60); do
  if timeout 5 adb shell cmd package list packages >/dev/null 2>&1; then
    package_ready=1
    break
  fi
  sleep 3
done
if [[ "$package_ready" -ne 1 ]]; then
  echo "::error::Android package manager did not become ready."
  exit 1
fi

run_integration_file() {
  local test_file="$1"
  local expected_name="$2"
  local expected_summary="$3"
  local log_file="$4"
  local test_status=0

  echo "::group::Android integration test: $test_file"
  set +e
  timeout 900 flutter test --no-pub --concurrency=1 -d emulator-5554 "$test_file" > "$log_file" 2>&1
  test_status=$?
  set -e
  cat "$log_file"
  echo "::endgroup::"

  if [[ "$test_status" -eq 0 ]]; then
    return 0
  fi

  if grep -Fq "$expected_name" "$log_file" &&
     grep -Fq "$expected_summary" "$log_file" &&
     grep -Fq "Error waiting for a debug connection: The log reader stopped unexpectedly" "$log_file" &&
     ! grep -E "Some tests failed|Test failed|Exception caught by flutter test|Expected:|Actual:|Failure:" "$log_file"; then
    echo "::warning::All asserted tests passed; only the known post-test debug log-reader teardown failed."
    return 0
  fi

  echo "::error::Android integration test failed: $test_file (exit $test_status)"
  return "$test_status"
}

run_integration_file \
  integration_test/database_android_integration_test.dart \
  "Android native SQLite persists academic rows and attachment BLOBs after reopen" \
  "1 test passed." \
  android-sqlite-integration.log

run_integration_file \
  integration_test/document_viewer_android_integration_test.dart \
  "Android Office handoff returns a typed status and preserves launched file" \
  "2 tests passed." \
  android-document-integration.log

echo "Installing the obfuscated x86_64 QA Release APK to exercise R8 at runtime..."
release_apk="build/app/outputs/flutter-apk/app-x86_64-release.apk"
test -s "$release_apk"
adb install -r "$release_apk"
adb shell am force-stop com.arfatalkamli.academicos || true
adb shell monkey -p com.arfatalkamli.academicos 1
sleep 8

app_pid="$(adb shell pidof com.arfatalkamli.academicos | tr -d '\r' || true)"
if [[ -z "$app_pid" ]]; then
  echo "::error::Obfuscated QA Release process did not remain alive after launch."
  adb logcat -d -t 2500 || true
  exit 1
fi

adb shell dumpsys activity activities | grep -F "com.arfatalkamli.academicos" | head -n 10 || true
echo "Android emulator SQLite/document integration and obfuscated QA Release install/launch checks passed. Package PID: $app_pid"
