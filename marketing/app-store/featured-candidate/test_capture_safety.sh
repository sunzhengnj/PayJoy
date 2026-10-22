#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

cat > "$test_dir/xcrun" <<'STUB'
#!/bin/zsh
print -r -- "$@" >> "$PAYJOY_XCRUN_LOG"
if [[ "${PAYJOY_XCRUN_MODE:-}" == 'two_booted' && "$*" == 'simctl list devices booted' ]]; then
    print 'iPhone A (Booted)'
    print 'iPhone B (Booted)'
    exit 0
fi
if [[ "${PAYJOY_XCRUN_MODE:-}" == 'reuse_booted' ]]; then
    if [[ "$*" == 'simctl list devices booted' ]]; then
        print 'PayJoy (test-device) (Booted)'
        print 'Other iPhone (other-device) (Booted)'
    fi
    exit 0
fi
if [[ "${PAYJOY_XCRUN_MODE:-}" == 'migration_failed' ]]; then
    if [[ "$*" == 'simctl bootstatus test-device -b' ]]; then
        print 'Status=3 isTerminal=YES'
        print 'Data Migration Failed'
    fi
    exit 0
fi
if [[ "${PAYJOY_XCRUN_MODE:-}" == 'boot_failed' ]]; then
    if [[ "$*" == 'simctl boot test-device' || "$*" == 'simctl bootstatus test-device -b' ]]; then
        print -u2 'Unable to finish starting device'
        exit 64
    fi
    exit 0
fi
if [[ "${PAYJOY_XCRUN_MODE:-}" == 'capture_times' ]]; then
    exit 0
fi
exit 88
STUB
chmod +x "$test_dir/xcrun"
cat > "$test_dir/sleep" <<'STUB'
#!/bin/zsh
exit 0
STUB
chmod +x "$test_dir/sleep"
cat > "$test_dir/pgrep" <<'STUB'
#!/bin/zsh
[[ "${PAYJOY_TEST_BUILD_RUNNING:-}" == '1' ]]
STUB
chmod +x "$test_dir/pgrep"

if env -u PAYJOY_CAPTURE_HOST_READY PATH="$test_dir:$PATH" PAYJOY_XCRUN_LOG="$test_dir/xcrun.log" \
    "$script_dir/capture.sh" test-device test-app "$test_dir/output" featured-home \
    > "$test_dir/capture.log" 2>&1; then
    print -u2 'Capture unexpectedly started without host readiness.'
    exit 1
fi

if [[ -s "$test_dir/xcrun.log" ]]; then
    print -u2 'Capture touched Simulator tooling before checking host readiness.'
    exit 1
fi

if ! rg -q 'PAYJOY_CAPTURE_HOST_READY=1' "$test_dir/capture.log"; then
    print -u2 'Capture did not explain how to run on a ready test host.'
    exit 1
fi

if PAYJOY_CAPTURE_HOST_READY=1 PAYJOY_TEST_BUILD_RUNNING=1 \
    PATH="$test_dir:$PATH" PAYJOY_XCRUN_LOG="$test_dir/build-commands.log" \
    "$script_dir/capture.sh" test-device test-app "$test_dir/output" featured-home \
    > "$test_dir/capture.log" 2>&1; then
    print -u2 'Capture unexpectedly started during an active build or test.'
    exit 1
fi
if [[ -s "$test_dir/build-commands.log" ]]; then
    print -u2 'Capture touched Simulator tooling during an active build or test.'
    exit 1
fi
if ! rg -q 'build or test is running' "$test_dir/capture.log"; then
    print -u2 'Capture did not explain why the active build blocks startup.'
    exit 1
fi

if PAYJOY_CAPTURE_HOST_READY=1 PAYJOY_XCRUN_MODE=two_booted \
    PATH="$test_dir:$PATH" PAYJOY_XCRUN_LOG="$test_dir/xcrun.log" \
    "$script_dir/capture.sh" test-device test-app "$test_dir/output" featured-home \
    > "$test_dir/capture.log" 2>&1; then
    print -u2 'Capture unexpectedly started with two simulators booted.'
    exit 1
fi

if rg -q '^simctl boot ' "$test_dir/xcrun.log"; then
    print -u2 'Capture tried to boot a third simulator.'
    exit 1
fi

if ! rg -q 'Two simulators are already booted' "$test_dir/capture.log"; then
    print -u2 'Capture did not explain the two-simulator limit.'
    exit 1
fi

PAYJOY_CAPTURE_HOST_READY=1 PAYJOY_XCRUN_MODE=capture_times \
    PATH="$test_dir:$PATH" PAYJOY_XCRUN_LOG="$test_dir/time-commands.log" \
    "$script_dir/capture.sh" test-device test-app "$test_dir/output" \
    home-after-midnight weekly-echo featured-home > "$test_dir/capture.log" 2>&1
actual_times="$(rg '^simctl status_bar test-device override --time' "$test_dir/time-commands.log" | sed -E "s/.*--time ([0-9:]+).*/\1/")"
expected_times=$'00:18\n19:24\n15:24'
if [[ "$actual_times" != "$expected_times" ]]; then
    print -u2 "Status bar times did not match screenshot fixture clocks: $actual_times"
    exit 1
fi

if rg -q '^simctl boot ' "$test_dir/time-commands.log"; then
    print -u2 'Capture booted before starting its boot-status monitor.'
    exit 1
fi
if ! rg -q '^simctl bootstatus test-device -b$' "$test_dir/time-commands.log"; then
    print -u2 'Capture did not start and monitor boot in one operation.'
    exit 1
fi

if ! PAYJOY_CAPTURE_HOST_READY=1 PAYJOY_XCRUN_MODE=reuse_booted \
    PATH="$test_dir:$PATH" PAYJOY_XCRUN_LOG="$test_dir/reuse-commands.log" \
    "$script_dir/capture.sh" test-device test-app "$test_dir/output" featured-home \
    > "$test_dir/capture.log" 2>&1; then
    print -u2 'Capture rejected an already running test device.'
    cat "$test_dir/capture.log" >&2
    exit 1
fi
if rg -q '^simctl (boot|bootstatus|shutdown) ' "$test_dir/reuse-commands.log"; then
    print -u2 'Capture restarted or shut down an already running device.'
    exit 1
fi
if ! rg -q '^simctl io test-device screenshot ' "$test_dir/reuse-commands.log"; then
    print -u2 'Capture did not reuse the existing test device.'
    exit 1
fi
if ! rg -q '^simctl status_bar test-device clear$' "$test_dir/reuse-commands.log"; then
    print -u2 'Capture did not clear its status-bar override on a reused device.'
    exit 1
fi

for failure_mode in migration_failed boot_failed; do
    if PAYJOY_CAPTURE_HOST_READY=1 PAYJOY_XCRUN_MODE="$failure_mode" \
        PATH="$test_dir:$PATH" PAYJOY_XCRUN_LOG="$test_dir/$failure_mode.log" \
        "$script_dir/capture.sh" test-device test-app "$test_dir/output" featured-home \
        > "$test_dir/capture.log" 2>&1; then
        print -u2 "Capture continued after $failure_mode."
        exit 1
    fi
    if rg -q '^simctl (install|launch|io) ' "$test_dir/$failure_mode.log"; then
        print -u2 "Capture reached app installation or capture after $failure_mode."
        exit 1
    fi
    if ! rg -q '^simctl shutdown test-device$' "$test_dir/$failure_mode.log"; then
        print -u2 "Capture left its partially started device running after $failure_mode."
        exit 1
    fi
done

print 'Capture host guard passed.'
