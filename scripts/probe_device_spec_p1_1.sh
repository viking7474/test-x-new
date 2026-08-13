#!/bin/sh
# Runtime evidence collector for DeviceSpec P1.1.
# Run on the jailbroken device as root.

set -eu

MODE="${1:-verify}"
PRIMARY_LOG="/var/mobile/Library/TLinkIOS/aida64_debug.log"
FALLBACK_LOG="/tmp/aida64_debug.log"
FLAG="/tmp/px_debug_aida64"

find_log() {
    if [ -f "$PRIMARY_LOG" ]; then
        printf '%s\n' "$PRIMARY_LOG"
    elif [ -f "$FALLBACK_LOG" ]; then
        printf '%s\n' "$FALLBACK_LOG"
    else
        return 1
    fi
}

case "$MODE" in
    prepare)
        touch "$FLAG"
        rm -f "$PRIMARY_LOG" "$FALLBACK_LOG"
        cat <<'EOF'
DeviceSpec P1.1 probe prepared.

1. Force-close the scoped target app.
2. Launch it again so PXFileDebugAIDA64Enabled observes the flag.
3. Open the CPU, memory and system-information screens.
4. Run this script again with: probe_device_spec_p1_1.sh verify
EOF
        ;;

    verify)
        LOG_PATH="$(find_log || true)"
        if [ -z "$LOG_PATH" ]; then
            echo "FAIL: no AIDA64 debug log found" >&2
            echo "Run: $0 prepare, then relaunch and exercise the scoped app." >&2
            exit 2
        fi

        echo "=== DeviceSpec P1.1 runtime probe ==="
        echo "log: $LOG_PATH"

        if ! grep -q '\[DeviceSpec.provider\] registered=1 original=1' "$LOG_PATH"; then
            echo "FAIL: DeviceSpec coordinator provider was not proven registered" >&2
            grep '\[DeviceSpec.provider\]' "$LOG_PATH" 2>/dev/null || true
            exit 1
        fi
        echo "PASS: coordinator provider registered with original pointer"

        RESULT_LINES="$(grep '\[DeviceSpec.sysctlbyname.result\]' "$LOG_PATH" 2>/dev/null || true)"
        if [ -z "$RESULT_LINES" ]; then
            echo "FAIL: no terminal DeviceSpec sysctlbyname result was recorded" >&2
            exit 1
        fi

        SUCCESS_LINES="$(printf '%s\n' "$RESULT_LINES" | grep ' result=0 ' || true)"
        if [ -z "$SUCCESS_LINES" ]; then
            echo "FAIL: DeviceSpec handled requests, but none completed successfully" >&2
            printf '%s\n' "$RESULT_LINES"
            exit 1
        fi
        echo "PASS: at least one DeviceSpec sysctlbyname request completed successfully"

        CPU_LINES="$(printf '%s\n' "$SUCCESS_LINES" | grep -E 'key=hw\.(physicalcpu|physicalcpu_max|logicalcpu|logicalcpu_max|ncpu|activecpu|cputype|cpusubtype|cpufamily|cachelinesize|l1icachesize|l1dcachesize|l2cachesize)' || true)"
        MEMORY_LINES="$(printf '%s\n' "$SUCCESS_LINES" | grep -E 'key=(hw\.(memsize|physmem)|vm\.swapusage)' || true)"

        if [ -n "$CPU_LINES" ]; then
            echo "PASS: CPU surface hit recorded"
        else
            echo "WARN: no successful CPU surface hit; open the app's CPU screen and verify again"
        fi

        if [ -n "$MEMORY_LINES" ]; then
            echo "PASS: memory surface hit recorded"
        else
            echo "WARN: no successful memory surface hit; open the app's memory screen and verify again"
        fi

        BAD_CPU_PROFILE="$(printf '%s\n' "$CPU_LINES" | grep ' profile=<none> ' || true)"
        if [ -n "$BAD_CPU_PROFILE" ]; then
            echo "FAIL: a CPU key was handled without a canonical CPU profile" >&2
            printf '%s\n' "$BAD_CPU_PROFILE" >&2
            exit 1
        fi

        echo
        echo "Successful keys:"
        printf '%s\n' "$SUCCESS_LINES" \
            | sed -n 's/.*key=\([^ ]*\).*/\1/p' \
            | sort -u \
            | sed 's/^/  - /'

        echo
        echo "PASS: DeviceSpec P1.1 runtime evidence is valid"
        ;;

    cleanup)
        rm -f "$FLAG"
        echo "Removed $FLAG. Relaunch target apps to disable AIDA64 file-debug logging."
        ;;

    *)
        echo "usage: $0 {prepare|verify|cleanup}" >&2
        exit 2
        ;;
esac
