#!/bin/sh
# Runtime evidence collector for DeviceSpec P1.2 immutable snapshot generations.
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
DeviceSpec P1.2 probe prepared.

1. Force-close the scoped target app.
2. Launch it and open CPU, memory, display and GPU information.
3. Change to another complete DeviceModel profile while the app is alive.
4. Return to the target app and exercise those screens again.
5. Run: probe_device_spec_p1_2.sh verify
EOF
        ;;

    verify)
        LOG_PATH="$(find_log || true)"
        if [ -z "$LOG_PATH" ]; then
            echo "FAIL: no AIDA64 debug log found" >&2
            echo "Run: $0 prepare, then relaunch and exercise the scoped app." >&2
            exit 2
        fi

        echo "=== DeviceSpec P1.2 runtime probe ==="
        echo "log: $LOG_PATH"

        if ! grep -q '\[DeviceSpec.provider\] registered=1 original=1' "$LOG_PATH"; then
            echo "FAIL: coordinator provider registration was not proven" >&2
            exit 1
        fi
        echo "PASS: coordinator provider registered"

        SNAPSHOT_LINES="$(grep '\[DeviceSpec.snapshot\]' "$LOG_PATH" 2>/dev/null || true)"
        if [ -z "$SNAPSHOT_LINES" ]; then
            echo "FAIL: no immutable snapshot publication evidence" >&2
            exit 1
        fi

        BAD_BUILD="$(printf '%s\n' "$SNAPSHOT_LINES" | grep -E 'source=(exception|missing-model|missing-specs)' || true)"
        if [ -n "$BAD_BUILD" ]; then
            echo "FAIL: snapshot construction failed closed during the probe" >&2
            printf '%s\n' "$BAD_BUILD" >&2
            exit 1
        fi

        ENABLED_LINES="$(printf '%s\n' "$SNAPSHOT_LINES" | grep ' enabled=1 ' || true)"
        if [ -z "$ENABLED_LINES" ]; then
            echo "FAIL: no enabled DeviceSpec snapshot was published" >&2
            printf '%s\n' "$SNAPSHOT_LINES" >&2
            exit 1
        fi
        echo "PASS: enabled snapshot publication recorded"

        BAD_ENABLED="$(printf '%s\n' "$ENABLED_LINES" | grep -E 'profile=<none>|model=<none>|specs=0([[:space:]]|$)' || true)"
        if [ -n "$BAD_ENABLED" ]; then
            echo "FAIL: enabled snapshot has incomplete identity/spec state" >&2
            printf '%s\n' "$BAD_ENABLED" >&2
            exit 1
        fi
        echo "PASS: enabled snapshots contain profile, model and specs"

        published_generation_sequence="$(printf '%s\n' "$ENABLED_LINES" \
            | sed -n 's/.*generation=\([0-9][0-9]*\).*/\1/p')"
        if [ -z "$published_generation_sequence" ]; then
            echo "FAIL: snapshot generations could not be parsed" >&2
            exit 1
        fi

        # Publication is monotonic in source, but file writes happen after the
        # publication lock and concurrent threads may append evidence out of order.
        # Validate uniqueness here without treating log order as publication order.
        published_generations="$(printf '%s\n' "$published_generation_sequence" | sort -n -u)"
        raw_generation_count="$(printf '%s\n' "$published_generation_sequence" | wc -l | tr -d ' ')"
        unique_generation_count="$(printf '%s\n' "$published_generations" | wc -l | tr -d ' ')"
        if [ "$raw_generation_count" -ne "$unique_generation_count" ]; then
            echo "FAIL: duplicate snapshot publication generation was logged" >&2
            exit 1
        fi
        echo "PASS: published generation IDs are unique"

        RESULT_LINES="$(grep '\[DeviceSpec.sysctlbyname.result\]' "$LOG_PATH" 2>/dev/null || true)"
        if [ -z "$RESULT_LINES" ]; then
            echo "FAIL: no terminal sysctl result evidence" >&2
            exit 1
        fi

        result_generations="$(printf '%s\n' "$RESULT_LINES" \
            | sed -n 's/.*generation=\([0-9][0-9]*\).*/\1/p' \
            | sort -n -u)"
        if [ -z "$result_generations" ]; then
            echo "FAIL: sysctl result evidence has no generation field" >&2
            exit 1
        fi

        unknown_generation=""
        for generation in $result_generations; do
            if ! printf '%s\n' "$published_generations" | grep -qx "$generation"; then
                unknown_generation="$generation"
                break
            fi
        done
        if [ -n "$unknown_generation" ]; then
            echo "FAIL: sysctl result references unpublished generation $unknown_generation" >&2
            exit 1
        fi
        echo "PASS: every sysctl result belongs to a published snapshot"

        latest_generation="$(printf '%s\n' "$published_generations" | tail -n 1)"
        if ! printf '%s\n' "$RESULT_LINES" | grep -q "generation=$latest_generation "; then
            echo "FAIL: latest snapshot generation has no exercised sysctl result" >&2
            echo "Open CPU/memory screens after the final profile change and verify again." >&2
            exit 1
        fi
        echo "PASS: latest generation was exercised"

        generation_count="$(printf '%s\n' "$published_generations" | wc -l | tr -d ' ')"
        if [ "$generation_count" -lt 2 ]; then
            echo "WARN: only one enabled generation observed; repeat with a live profile switch"
        else
            echo "PASS: live profile reload published multiple enabled generations"
        fi

        echo
        echo "Published enabled generations:"
        printf '%s\n' "$published_generations" | sed 's/^/  - /'
        echo
        echo "PASS: DeviceSpec P1.2 runtime evidence is valid"
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
