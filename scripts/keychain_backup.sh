#!/bin/bash
#
# keychain_backup.sh - Dynamic Entitlement Resign Wrapper for KeychainHelper
#
# This script extracts keychain-access-groups entitlements from a target app,
# resigns the KeychainHelper binary with those entitlements, and executes it.
#
# Usage:
#   keychain_backup.sh backup <bundleID> <backup_file>
#   keychain_backup.sh restore <bundleID> <backup_file> [--overwrite]
#   keychain_backup.sh wipe <bundleID>
#   keychain_backup.sh list <bundleID>
#
# Requirements:
#   - Jailbroken iOS device with AMFI patches
#   - ldid installed (/usr/bin/ldid or rootless path)
#   - plutil installed (comes with iOS)
#

# Removed 'set -e' for better error handling - we handle errors explicitly

# === Fixed shell environment ===
PATH="/usr/bin:/bin:/usr/sbin:/sbin:/var/jb/usr/bin:/var/jb/bin:/private/preboot/jb/usr/bin:/private/preboot/jb/bin"
export PATH
IFS=$' \t\n'
export -n IFS 2>/dev/null || true
unset CDPATH ENV BASH_ENV GLOBIGNORE
LC_ALL=C
LANG=C
export LC_ALL LANG
umask 077

# === Configuration ===
readonly HELPER_TOOL_PATH="/Library/WeaponX/backup_helper"
readonly PX_WORKSPACE_PARENT="/private/var/tmp"
readonly PX_WORKSPACE_PREFIX=".weaponx-keychain-helper."
VERBOSE=0

PX_WORKSPACE_PATH=""
PX_WORKSPACE_DEVICE=""
PX_WORKSPACE_INODE=""
PX_WORKSPACE_UID=""
PX_WORKSPACE_GID=""
PX_WORKSPACE_MODE=""
PX_WORKSPACE_LINKS=""
PX_WORKSPACE_PARENT_DEVICE=""
PX_WORKSPACE_PARENT_INODE=""
PX_WORKSPACE_ACTIVE=0
PX_WORKSPACE_CREATE_ATTEMPTED=0

readonly PX_KEYCHAIN_EXIT_COMPLETED=0
readonly PX_KEYCHAIN_EXIT_PARTIAL=10
readonly PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS=20
readonly PX_KEYCHAIN_EXIT_INVALID_INPUT=21
readonly PX_KEYCHAIN_EXIT_ACCESS_DENIED=30
readonly PX_KEYCHAIN_EXIT_OPERATION_FAILED=40
readonly PX_KEYCHAIN_EXIT_PROTOCOL_FAILURE=50
readonly PX_KEYCHAIN_EXIT_HELPER_UNAVAILABLE=60
readonly PX_KEYCHAIN_EXIT_TARGET_UNAVAILABLE=61
readonly PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE=62
readonly PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE=63
readonly PX_KEYCHAIN_EXIT_SIGNING_FAILURE=64
readonly PX_KEYCHAIN_EXIT_DEPENDENCY_UNAVAILABLE=65

# Optional subset of keychain groups (CSV) provided by caller.
OVERRIDE_KEYCHAIN_GROUPS=""
OVERRIDE_KEYCHAIN_GROUPS_PRESENT=0
PX_REQUESTED_GROUPS_CSV=""
PX_EFFECTIVE_GROUPS_CSV=""
PX_EFFECTIVE_ENT_PATH=""
PX_APP_IDENTIFIER=""
PX_APP_GROUPS_CSV=""

# === Color Output ===
# Only use colors if running in a TTY (interactive terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_verbose() {
    if [ "$VERBOSE" -eq 1 ]; then
        echo -e "[DEBUG] $1" >&2
    fi
}

PX_STAT_PATH=""
PX_MKTEMP_PATH=""
PX_CP_PATH=""
PX_CMP_PATH=""
PX_CHMOD_PATH=""
PX_RM_PATH=""
PX_RMDIR_PATH=""
PX_PLUTIL_PATH=""
PX_LDID_PATH=""
PX_GREP_PATH=""
PX_SED_PATH=""
PX_METADATA_READY=0
PX_DEPENDENCIES_READY=0

px_mode_is_safe_executable() {
    local mode="$1"
    case "$mode" in
        ""|*[!0-7]*) return 1 ;;
    esac
    local mode_value=$((8#$mode))
    [ $((mode_value & 0022)) -eq 0 ]
}

px_bootstrap_stat() {
    local candidates=(
        "/usr/bin/stat"
        "/bin/stat"
        "/var/jb/usr/bin/stat"
        "/private/preboot/jb/usr/bin/stat"
    )
    local candidate parent basename physical_parent resolved output
    local device inode uid gid mode size links mtime ctime extra
    for candidate in "${candidates[@]}"; do
        [ -f "$candidate" ] || continue
        [ ! -L "$candidate" ] || continue
        [ -x "$candidate" ] || continue
        [ -s "$candidate" ] || continue
        parent="${candidate%/*}"
        basename="${candidate##*/}"
        physical_parent=$(cd -P "$parent" 2>/dev/null && pwd -P) || continue
        resolved="${physical_parent%/}/$basename"
        [ -f "$resolved" ] || continue
        [ ! -L "$resolved" ] || continue
        [ -x "$resolved" ] || continue
        output=$("$resolved" -f '%d|%i|%u|%g|%Lp|%z|%l|%m|%c' "$resolved" 2>/dev/null) || continue
        case "$output" in *$'\n'*|*$'\r'*) continue ;; esac
        IFS='|' read -r device inode uid gid mode size links mtime ctime extra <<< "$output"
        [ -z "$extra" ] || continue
        [ -n "$device" ] && [ -n "$inode" ] && [ -n "$uid" ] && [ -n "$gid" ] || continue
        [ -n "$size" ] && [ -n "$links" ] && [ -n "$mtime" ] && [ -n "$ctime" ] || continue
        case "$device:$inode:$uid:$gid:$size:$links:$mtime:$ctime" in
            *[!0-9:]*|::*|:*:) continue ;;
        esac
        [ "$uid" -eq 0 ] || continue
        [ "$size" -gt 0 ] || continue
        px_mode_is_safe_executable "$mode" || continue
        PX_STAT_PATH="$resolved"
        return 0
    done
    return 1
}

px_valid_snapshot_prefix() {
    local prefix="$1"
    [ -n "$prefix" ] && [ "${#prefix}" -le 64 ] || return 1
    case "$prefix" in
        PX_*) ;;
        *) return 1 ;;
    esac
    case "$prefix" in
        *[!A-Z0-9_]*) return 1 ;;
    esac
    return 0
}

px_stat_snapshot() {
    local path="$1"
    local prefix="$2"
    [ "$PX_METADATA_READY" -eq 1 ] || return 1
    [ -n "$path" ] || return 1
    px_valid_snapshot_prefix "$prefix" || return 1
    local output device inode uid gid mode size links mtime ctime extra
    output=$("$PX_STAT_PATH" -f '%d|%i|%u|%g|%Lp|%z|%l|%m|%c' "$path" 2>/dev/null) || return 1
    case "$output" in *$'\n'*|*$'\r'*) return 1 ;; esac
    IFS='|' read -r device inode uid gid mode size links mtime ctime extra <<< "$output"
    [ -z "$extra" ] || return 1
    [ -n "$device" ] && [ -n "$inode" ] && [ -n "$uid" ] && [ -n "$gid" ] || return 1
    [ -n "$size" ] && [ -n "$links" ] && [ -n "$mtime" ] && [ -n "$ctime" ] || return 1
    case "$device:$inode:$uid:$gid:$size:$links:$mtime:$ctime" in
        *[!0-9:]*|::*|:*:) return 1 ;;
    esac
    case "$mode" in ""|*[!0-7]*) return 1 ;; esac
    printf -v "${prefix}_DEVICE" '%s' "$device"
    printf -v "${prefix}_INODE" '%s' "$inode"
    printf -v "${prefix}_UID" '%s' "$uid"
    printf -v "${prefix}_GID" '%s' "$gid"
    printf -v "${prefix}_MODE" '%s' "$mode"
    printf -v "${prefix}_SIZE" '%s' "$size"
    printf -v "${prefix}_LINKS" '%s' "$links"
    printf -v "${prefix}_MTIME" '%s' "$mtime"
    printf -v "${prefix}_CTIME" '%s' "$ctime"
    return 0
}

px_same_identity() {
    px_valid_snapshot_prefix "$1" || return 1
    px_valid_snapshot_prefix "$2" || return 1
    local left="$1"
    local right="$2"
    local field left_value right_value
    for field in DEVICE INODE UID GID MODE LINKS; do
        eval "left_value=\${${left}_${field}}"
        eval "right_value=\${${right}_${field}}"
        [ "$left_value" = "$right_value" ] || return 1
    done
    return 0
}

px_same_complete_snapshot() {
    px_valid_snapshot_prefix "$1" || return 1
    px_valid_snapshot_prefix "$2" || return 1
    local left="$1"
    local right="$2"
    px_same_identity "$left" "$right" || return 1
    local field left_value right_value
    for field in SIZE MTIME CTIME; do
        eval "left_value=\${${left}_${field}}"
        eval "right_value=\${${right}_${field}}"
        [ "$left_value" = "$right_value" ] || return 1
    done
    return 0
}

px_physical_directory() {
    local directory="$1"
    [ -n "$directory" ] || return 1
    case "$directory" in /*) ;; *) return 1 ;; esac
    case "$directory" in *$'\n'*|*$'\r'*) return 1 ;; esac
    [ "${#directory}" -le 4096 ] || return 1
    local physical
    physical=$(cd -P "$directory" 2>/dev/null && pwd -P) || return 1
    case "$physical" in /*) ;; *) return 1 ;; esac
    PX_PHYSICAL_DIRECTORY="$physical"
    return 0
}

px_resolve_trusted_utility() {
    local variable_name="$1"
    shift
    local candidate parent basename resolved
    for candidate in "$@"; do
        case "$candidate" in /*) ;; *) continue ;; esac
        [ ! -L "$candidate" ] || continue
        parent="${candidate%/*}"
        basename="${candidate##*/}"
        px_physical_directory "$parent" || continue
        resolved="${PX_PHYSICAL_DIRECTORY%/}/$basename"
        [ -f "$resolved" ] || continue
        [ ! -L "$resolved" ] || continue
        [ -x "$resolved" ] || continue
        [ -s "$resolved" ] || continue
        px_stat_snapshot "$resolved" PX_UTILITY || continue
        px_stat_snapshot "$PX_PHYSICAL_DIRECTORY" PX_UTILITY_PARENT || continue
        [ "$PX_UTILITY_UID" -eq 0 ] || continue
        [ "$PX_UTILITY_PARENT_UID" -eq 0 ] || continue
        px_mode_is_safe_executable "$PX_UTILITY_MODE" || continue
        px_mode_is_safe_executable "$PX_UTILITY_PARENT_MODE" || continue
        printf -v "$variable_name" '%s' "$resolved"
        return 0
    done
    return 1
}

px_initialize_metadata_boundary() {
    [ "$PX_METADATA_READY" -eq 0 ] || return 0
    px_bootstrap_stat || return 1
    PX_METADATA_READY=1
    px_stat_snapshot "$PX_STAT_PATH" PX_STAT_SELF || return 1
    [ "$PX_STAT_SELF_UID" -eq 0 ] || return 1
    [ "$PX_STAT_SELF_SIZE" -gt 0 ] || return 1
    px_mode_is_safe_executable "$PX_STAT_SELF_MODE" || return 1
    px_physical_directory "${PX_STAT_PATH%/*}" || return 1
    px_stat_snapshot "$PX_PHYSICAL_DIRECTORY" PX_STAT_PARENT || return 1
    [ "$PX_STAT_PARENT_UID" -eq 0 ] || return 1
    px_mode_is_safe_executable "$PX_STAT_PARENT_MODE" || return 1
    readonly PX_STAT_PATH
    return 0
}

px_resolve_trusted_dependencies() {
    [ "$PX_DEPENDENCIES_READY" -eq 0 ] || return 0
    px_resolve_trusted_utility PX_MKTEMP_PATH \
        /usr/bin/mktemp /bin/mktemp /var/jb/usr/bin/mktemp /private/preboot/jb/usr/bin/mktemp || return 1
    px_resolve_trusted_utility PX_CP_PATH \
        /bin/cp /usr/bin/cp /var/jb/bin/cp /var/jb/usr/bin/cp /private/preboot/jb/bin/cp || return 1
    px_resolve_trusted_utility PX_CMP_PATH \
        /usr/bin/cmp /bin/cmp /var/jb/usr/bin/cmp /private/preboot/jb/usr/bin/cmp || return 1
    px_resolve_trusted_utility PX_CHMOD_PATH \
        /bin/chmod /usr/bin/chmod /var/jb/bin/chmod /private/preboot/jb/bin/chmod || return 1
    px_resolve_trusted_utility PX_RM_PATH \
        /bin/rm /usr/bin/rm /var/jb/bin/rm /private/preboot/jb/bin/rm || return 1
    px_resolve_trusted_utility PX_RMDIR_PATH \
        /bin/rmdir /usr/bin/rmdir /var/jb/bin/rmdir /private/preboot/jb/bin/rmdir || return 1
    px_resolve_trusted_utility PX_PLUTIL_PATH \
        /usr/bin/plutil /var/jb/usr/bin/plutil /private/preboot/jb/usr/bin/plutil /bin/plutil || return 1
    px_resolve_trusted_utility PX_LDID_PATH \
        /usr/bin/ldid /var/jb/usr/bin/ldid /private/preboot/jb/usr/bin/ldid /bin/ldid || return 1
    px_resolve_trusted_utility PX_GREP_PATH \
        /usr/bin/grep /bin/grep /var/jb/usr/bin/grep /private/preboot/jb/usr/bin/grep || return 1
    px_resolve_trusted_utility PX_SED_PATH \
        /usr/bin/sed /bin/sed /var/jb/usr/bin/sed /private/preboot/jb/usr/bin/sed || return 1
    readonly PX_MKTEMP_PATH PX_CP_PATH PX_CMP_PATH PX_CHMOD_PATH PX_RM_PATH PX_RMDIR_PATH
    readonly PX_PLUTIL_PATH PX_LDID_PATH PX_GREP_PATH PX_SED_PATH
    PX_DEPENDENCIES_READY=1
    return 0
}

px_validate_installed_helper() {
    case "$HELPER_TOOL_PATH" in /*) ;; *) return 1 ;; esac
    [ -f "$HELPER_TOOL_PATH" ] || return 1
    [ ! -L "$HELPER_TOOL_PATH" ] || return 1
    [ -x "$HELPER_TOOL_PATH" ] || return 1
    [ -s "$HELPER_TOOL_PATH" ] || return 1
    local parent="${HELPER_TOOL_PATH%/*}"
    local basename="${HELPER_TOOL_PATH##*/}"
    px_physical_directory "$parent" || return 1
    local resolved="${PX_PHYSICAL_DIRECTORY%/}/$basename"
    [ -f "$resolved" ] || return 1
    [ ! -L "$resolved" ] || return 1
    [ -x "$resolved" ] || return 1
    px_stat_snapshot "$resolved" PX_INSTALLED_HELPER || return 1
    px_stat_snapshot "$PX_PHYSICAL_DIRECTORY" PX_INSTALLED_HELPER_PARENT || return 1
    [ "$PX_INSTALLED_HELPER_UID" -eq 0 ] || return 1
    [ "$PX_INSTALLED_HELPER_PARENT_UID" -eq 0 ] || return 1
    [ "$PX_INSTALLED_HELPER_LINKS" -eq 1 ] || return 1
    [ "$PX_INSTALLED_HELPER_SIZE" -gt 0 ] || return 1
    px_mode_is_safe_executable "$PX_INSTALLED_HELPER_MODE" || return 1
    px_mode_is_safe_executable "$PX_INSTALLED_HELPER_PARENT_MODE" || return 1
    PX_INSTALLED_HELPER_PATH="$resolved"
    return 0
}

normalize_helper_exit_status() {
    local raw_status="$1"
    case "$raw_status" in
        "$PX_KEYCHAIN_EXIT_COMPLETED") return "$PX_KEYCHAIN_EXIT_COMPLETED" ;;
        "$PX_KEYCHAIN_EXIT_PARTIAL") return "$PX_KEYCHAIN_EXIT_PARTIAL" ;;
        "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS") return "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS" ;;
        "$PX_KEYCHAIN_EXIT_INVALID_INPUT") return "$PX_KEYCHAIN_EXIT_INVALID_INPUT" ;;
        "$PX_KEYCHAIN_EXIT_ACCESS_DENIED") return "$PX_KEYCHAIN_EXIT_ACCESS_DENIED" ;;
        "$PX_KEYCHAIN_EXIT_OPERATION_FAILED") return "$PX_KEYCHAIN_EXIT_OPERATION_FAILED" ;;
        "$PX_KEYCHAIN_EXIT_PROTOCOL_FAILURE") return "$PX_KEYCHAIN_EXIT_PROTOCOL_FAILURE" ;;
        *)
            log_error "Unrecognized helper exit status: $raw_status; normalized to $PX_KEYCHAIN_EXIT_OPERATION_FAILED"
            return "$PX_KEYCHAIN_EXIT_OPERATION_FAILED"
            ;;
    esac
}

px_mode_is_exact() {
    local actual="$1"
    local expected="$2"
    while [ "${actual#0}" != "$actual" ]; do actual="${actual#0}"; done
    while [ "${expected#0}" != "$expected" ]; do expected="${expected#0}"; done
    [ "$actual" = "$expected" ]
}

px_parent_has_safe_sticky_semantics() {
    local mode="$1"
    case "$mode" in ""|*[!0-7]*) return 1 ;; esac
    local value=$((8#$mode))
    if [ $((value & 0022)) -ne 0 ]; then
        [ $((value & 01000)) -ne 0 ] || return 1
    fi
    return 0
}

px_directory_is_empty() (
    local directory="$1"
    shopt -s nullglob dotglob
    local entries=("$directory"/*)
    [ "${#entries[@]}" -eq 0 ]
)

px_workspace_path_has_authority() {
    local path="$1"
    [ -n "$path" ] && [ "${#path}" -le 4096 ] || return 1
    px_string_has_control_character "$path" && return 1
    case "$path" in
        "$PX_WORKSPACE_PARENT/$PX_WORKSPACE_PREFIX"????????) ;;
        *) return 1 ;;
    esac
    local basename="${path##*/}"
    case "$basename" in */*|""|.|..) return 1 ;; esac
    [ "${path%/*}" = "$PX_WORKSPACE_PARENT" ] || return 1
    return 0
}

px_validate_workspace_parent() {
    [ -d "$PX_WORKSPACE_PARENT" ] || return 1
    [ ! -L "$PX_WORKSPACE_PARENT" ] || return 1
    [ -x "$PX_WORKSPACE_PARENT" ] || return 1
    px_physical_directory "$PX_WORKSPACE_PARENT" || return 1
    [ "$PX_PHYSICAL_DIRECTORY" = "$PX_WORKSPACE_PARENT" ] || return 1
    px_stat_snapshot "$PX_WORKSPACE_PARENT" PX_WORKSPACE_PARENT_CURRENT || return 1
    [ "$PX_WORKSPACE_PARENT_CURRENT_UID" -eq 0 ] || return 1
    px_parent_has_safe_sticky_semantics "$PX_WORKSPACE_PARENT_CURRENT_MODE" || return 1
    return 0
}

px_discard_unactivated_workspace() {
    local path="$1"
    px_workspace_path_has_authority "$path" || return 1
    if [ -L "$path" ]; then
        "$PX_RM_PATH" -f "$path" >/dev/null 2>&1 || return 1
        return 0
    fi
    if [ -d "$path" ]; then
        px_directory_is_empty "$path" || return 1
        "$PX_RMDIR_PATH" "$path" >/dev/null 2>&1 || return 1
        return 0
    fi
    if [ -e "$path" ]; then
        return 1
    fi
    return 0
}

px_create_workspace() {
    [ "$PX_WORKSPACE_CREATE_ATTEMPTED" -eq 0 ] || return 1
    PX_WORKSPACE_CREATE_ATTEMPTED=1
    px_validate_workspace_parent || return 1
    px_stat_snapshot "$PX_WORKSPACE_PARENT" PX_WORKSPACE_PARENT_BEFORE || return 1

    local created
    created=$("$PX_MKTEMP_PATH" -d "$PX_WORKSPACE_PARENT/$PX_WORKSPACE_PREFIX"XXXXXXXX 2>/dev/null) || return 1
    case "$created" in *$'\n'*|*$'\r'*) return 1 ;; esac
    if ! px_workspace_path_has_authority "$created"; then
        px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
        return 1
    fi
    if [ -L "$created" ] || [ ! -d "$created" ]; then
        px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
        return 1
    fi

    px_stat_snapshot "$created" PX_WORKSPACE_NEW || {
        px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
        return 1
    }
    if ! px_mode_is_exact "$PX_WORKSPACE_NEW_MODE" 700; then
        "$PX_CHMOD_PATH" 700 "$created" >/dev/null 2>&1 || {
            px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
            return 1
        }
        px_stat_snapshot "$created" PX_WORKSPACE_NEW || {
            px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
            return 1
        }
    fi

    [ "$PX_WORKSPACE_NEW_UID" -eq "$EUID" ] || {
        px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
        return 1
    }
    px_mode_is_exact "$PX_WORKSPACE_NEW_MODE" 700 || {
        px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
        return 1
    }
    [ "$PX_WORKSPACE_NEW_DEVICE" = "$PX_WORKSPACE_PARENT_BEFORE_DEVICE" ] || {
        px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
        return 1
    }
    px_directory_is_empty "$created" || {
        px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
        return 1
    }
    px_validate_workspace_parent || {
        px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
        return 1
    }
    px_stat_snapshot "$PX_WORKSPACE_PARENT" PX_WORKSPACE_PARENT_AFTER || {
        px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
        return 1
    }
    px_same_identity PX_WORKSPACE_PARENT_BEFORE PX_WORKSPACE_PARENT_AFTER || {
        px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
        return 1
    }

    PX_WORKSPACE_PATH="$created"
    PX_WORKSPACE_DEVICE="$PX_WORKSPACE_NEW_DEVICE"
    PX_WORKSPACE_INODE="$PX_WORKSPACE_NEW_INODE"
    PX_WORKSPACE_UID="$PX_WORKSPACE_NEW_UID"
    PX_WORKSPACE_GID="$PX_WORKSPACE_NEW_GID"
    PX_WORKSPACE_MODE="$PX_WORKSPACE_NEW_MODE"
    PX_WORKSPACE_LINKS="$PX_WORKSPACE_NEW_LINKS"
    PX_WORKSPACE_PARENT_DEVICE="$PX_WORKSPACE_PARENT_AFTER_DEVICE"
    PX_WORKSPACE_PARENT_INODE="$PX_WORKSPACE_PARENT_AFTER_INODE"
    PX_WORKSPACE_ACTIVE=1
    return 0
}

px_validate_workspace_identity() {
    [ "$PX_WORKSPACE_ACTIVE" -eq 1 ] || return 1
    px_workspace_path_has_authority "$PX_WORKSPACE_PATH" || return 1
    [ -d "$PX_WORKSPACE_PATH" ] || return 1
    [ ! -L "$PX_WORKSPACE_PATH" ] || return 1
    px_validate_workspace_parent || return 1
    px_stat_snapshot "$PX_WORKSPACE_PARENT" PX_WORKSPACE_PARENT_LIVE || return 1
    [ "$PX_WORKSPACE_PARENT_LIVE_DEVICE" = "$PX_WORKSPACE_PARENT_DEVICE" ] || return 1
    [ "$PX_WORKSPACE_PARENT_LIVE_INODE" = "$PX_WORKSPACE_PARENT_INODE" ] || return 1
    px_stat_snapshot "$PX_WORKSPACE_PATH" PX_WORKSPACE_LIVE || return 1
    [ "$PX_WORKSPACE_LIVE_DEVICE" = "$PX_WORKSPACE_DEVICE" ] || return 1
    [ "$PX_WORKSPACE_LIVE_INODE" = "$PX_WORKSPACE_INODE" ] || return 1
    [ "$PX_WORKSPACE_LIVE_UID" = "$PX_WORKSPACE_UID" ] || return 1
    [ "$PX_WORKSPACE_LIVE_GID" = "$PX_WORKSPACE_GID" ] || return 1
    [ "$PX_WORKSPACE_LIVE_LINKS" = "$PX_WORKSPACE_LINKS" ] || return 1
    [ "$PX_WORKSPACE_LIVE_UID" -eq "$EUID" ] || return 1
    px_mode_is_exact "$PX_WORKSPACE_LIVE_MODE" 700 || return 1
    return 0
}

px_workspace_child_path() {
    local name="$1"
    case "$name" in
        app_ent.xml|helper_ent.plist|backup_helper|signed_helper_ent.plist|restore_input.plist) ;;
        *) return 1 ;;
    esac
    PX_WORKSPACE_CHILD_PATH="$PX_WORKSPACE_PATH/$name"
    return 0
}

px_require_workspace_child_absent() {
    local name="$1"
    px_validate_workspace_identity || return 1
    px_workspace_child_path "$name" || return 1
    [ ! -e "$PX_WORKSPACE_CHILD_PATH" ] || return 1
    [ ! -L "$PX_WORKSPACE_CHILD_PATH" ] || return 1
    return 0
}

px_validate_workspace_file() {
    local path="$1"
    local expected_mode="$2"
    local require_executable="$3"
    local require_nonzero="$4"
    px_validate_workspace_identity || return 1
    [ "${path%/*}" = "$PX_WORKSPACE_PATH" ] || return 1
    local name="${path##*/}"
    px_workspace_child_path "$name" || return 1
    [ "$path" = "$PX_WORKSPACE_CHILD_PATH" ] || return 1
    [ -f "$path" ] || return 1
    [ ! -L "$path" ] || return 1
    if [ "$require_executable" -eq 1 ]; then
        [ -x "$path" ] || return 1
    fi
    px_stat_snapshot "$path" PX_WORKSPACE_FILE || return 1
    [ "$PX_WORKSPACE_FILE_DEVICE" = "$PX_WORKSPACE_DEVICE" ] || return 1
    [ "$PX_WORKSPACE_FILE_UID" -eq "$EUID" ] || return 1
    [ "$PX_WORKSPACE_FILE_LINKS" -eq 1 ] || return 1
    px_mode_is_exact "$PX_WORKSPACE_FILE_MODE" "$expected_mode" || return 1
    if [ "$require_nonzero" -eq 1 ]; then
        [ "$PX_WORKSPACE_FILE_SIZE" -gt 0 ] || return 1
    fi
    px_validate_workspace_identity || return 1
    return 0
}

px_cleanup_workspace() {
    px_validate_workspace_identity || return 1
    local name child failed=0
    for name in restore_input.plist signed_helper_ent.plist backup_helper helper_ent.plist app_ent.xml; do
        px_workspace_child_path "$name" || return 1
        child="$PX_WORKSPACE_CHILD_PATH"
        if [ -L "$child" ]; then
            "$PX_RM_PATH" -f "$child" >/dev/null 2>&1 || failed=1
        elif [ -f "$child" ]; then
            "$PX_RM_PATH" -f "$child" >/dev/null 2>&1 || failed=1
        elif [ -e "$child" ]; then
            failed=1
        fi
    done
    [ "$failed" -eq 0 ] || return 1
    px_validate_workspace_identity || return 1
    px_directory_is_empty "$PX_WORKSPACE_PATH" || return 1
    "$PX_RMDIR_PATH" "$PX_WORKSPACE_PATH" >/dev/null 2>&1 || return 1
    PX_WORKSPACE_ACTIVE=0
    PX_WORKSPACE_PATH=""
    return 0
}

px_exit_trap() {
    local original_status=$?
    trap - EXIT
    if [ "$PX_WORKSPACE_ACTIVE" -eq 1 ]; then
        if ! px_cleanup_workspace; then
            log_error "Temporary workspace cleanup failed (original status: $original_status)"
            exit "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
        fi
    fi
    exit "$original_status"
}

trap px_exit_trap EXIT

# === Trusted ldid/plutil accessors ===
find_ldid() {
    [ "$PX_DEPENDENCIES_READY" -eq 1 ] || return 1
    printf '%s\n' "$PX_LDID_PATH"
}

find_plutil() {
    [ "$PX_DEPENDENCIES_READY" -eq 1 ] || return 1
    printf '%s\n' "$PX_PLUTIL_PATH"
}

# === Path and target validation ===
PX_TARGET_PATH=""
PX_TARGET_APP_BUNDLE=""
PX_TARGET_IS_SYSTEM=0
PX_APP_ENT_PATH=""
PX_HELPER_ENT_PATH=""
PX_WORKING_HELPER_PATH=""
PX_SIGNED_HELPER_ENT_PATH=""
PX_RESTORE_INPUT_PATH=""
PX_BACKUP_OUTPUT_PATH=""
PX_BACKUP_OUTPUT_PARENT=""
PX_BACKUP_OUTPUT_EXISTED=0

px_string_has_control_character() {
    local value="$1"
    case "$value" in
        *$'\n'*|*$'\r'*) return 0 ;;
    esac
    printf '%s' "$value" | "$PX_GREP_PATH" -q '[[:cntrl:]]'
}

px_validate_bundle_id() {
    local bundle_id="$1"
    [ -n "$bundle_id" ] || return 1
    [ "${#bundle_id}" -le 255 ] || return 1
    px_string_has_control_character "$bundle_id" && return 1
    case "$bundle_id" in
        *'/'*|*'\\'*|*[!A-Za-z0-9._-]*|.|..|-*) return 1 ;;
        [A-Za-z0-9]*) ;;
        *) return 1 ;;
    esac
    return 0
}

px_validate_safe_basename() {
    local basename="$1"
    [ -n "$basename" ] || return 1
    [ "${#basename}" -le 255 ] || return 1
    px_string_has_control_character "$basename" && return 1
    case "$basename" in
        */*|*'\\'*|.|..|-*) return 1 ;;
    esac
    return 0
}

px_validate_absolute_path_lexical() {
    local path="$1"
    [ -n "$path" ] || return 1
    [ "${#path}" -le 4096 ] || return 1
    case "$path" in /*) ;; *) return 1 ;; esac
    px_string_has_control_character "$path" && return 1
    local basename="${path##*/}"
    px_validate_safe_basename "$basename" || return 1
    local parent="${path%/*}"
    [ -n "$parent" ] || parent="/"
    PX_PATH_PARENT="$parent"
    PX_PATH_BASENAME="$basename"
    return 0
}

px_canonicalize_existing_file() {
    local path="$1"
    px_validate_absolute_path_lexical "$path" || return 1
    local raw_parent="$PX_PATH_PARENT"
    local basename="$PX_PATH_BASENAME"
    px_physical_directory "$raw_parent" || return 1
    local physical_parent="$PX_PHYSICAL_DIRECTORY"
    local canonical="${physical_parent%/}/$basename"
    [ -f "$canonical" ] || return 1
    [ ! -L "$canonical" ] || return 1
    [ -r "$canonical" ] || return 1
    px_stat_snapshot "$physical_parent" PX_CANONICAL_PARENT || return 1
    px_stat_snapshot "$canonical" PX_CANONICAL_FILE || return 1
    [ "$PX_CANONICAL_FILE_SIZE" -gt 0 ] || return 1
    PX_CANONICAL_PATH="$canonical"
    PX_CANONICAL_PARENT_PATH="$physical_parent"
    return 0
}

px_canonicalize_output_path() {
    local path="$1"
    px_validate_absolute_path_lexical "$path" || return 1
    local raw_parent="$PX_PATH_PARENT"
    local basename="$PX_PATH_BASENAME"
    px_physical_directory "$raw_parent" || return 1
    local physical_parent="$PX_PHYSICAL_DIRECTORY"
    [ -d "$physical_parent" ] || return 1
    [ -w "$physical_parent" ] || return 1
    px_stat_snapshot "$physical_parent" PX_OUTPUT_PARENT_INITIAL || return 1
    local canonical="${physical_parent%/}/$basename"
    [ ! -L "$canonical" ] || return 1
    if [ -e "$canonical" ]; then
        [ -f "$canonical" ] || return 1
        [ -w "$canonical" ] || return 1
        px_stat_snapshot "$canonical" PX_OUTPUT_FILE_INITIAL || return 1
        PX_BACKUP_OUTPUT_EXISTED=1
    else
        PX_BACKUP_OUTPUT_EXISTED=0
    fi
    PX_CANONICAL_OUTPUT_PATH="$canonical"
    PX_CANONICAL_OUTPUT_PARENT="$physical_parent"
    return 0
}

px_owner_is_app_trusted() {
    local uid="$1"
    [ "$uid" -eq 0 ] || [ "$uid" -eq 501 ]
}

px_validate_app_directory() {
    local directory="$1"
    [ -d "$directory" ] || return 1
    [ ! -L "$directory" ] || return 1
    [ -x "$directory" ] || return 1
    px_stat_snapshot "$directory" PX_APP_DIRECTORY || return 1
    px_owner_is_app_trusted "$PX_APP_DIRECTORY_UID" || return 1
    px_mode_is_safe_executable "$PX_APP_DIRECTORY_MODE" || return 1
    return 0
}

px_validate_info_plist() {
    local plist="$1"
    [ -f "$plist" ] || return 1
    [ ! -L "$plist" ] || return 1
    [ -r "$plist" ] || return 1
    px_stat_snapshot "$plist" PX_INFO_PLIST || return 1
    px_owner_is_app_trusted "$PX_INFO_PLIST_UID" || return 1
    px_mode_is_safe_executable "$PX_INFO_PLIST_MODE" || return 1
    [ "$PX_INFO_PLIST_LINKS" -eq 1 ] || return 1
    [ "$PX_INFO_PLIST_SIZE" -gt 0 ] || return 1
    [ "$PX_INFO_PLIST_SIZE" -le 16777216 ] || return 1
    return 0
}

px_read_info_value() {
    local plist="$1"
    local key="$2"
    px_validate_info_plist "$plist" || return 1
    px_stat_snapshot "$plist" PX_INFO_BEFORE || return 1
    local value
    value=$("$PX_PLUTIL_PATH" -key "$key" "$plist" 2>/dev/null)
    local status=$?
    px_stat_snapshot "$plist" PX_INFO_AFTER || return 1
    px_same_complete_snapshot PX_INFO_BEFORE PX_INFO_AFTER || return 1
    [ "$status" -eq 0 ] || return 1
    [ -n "$value" ] || return 1
    [ "${#value}" -le 4096 ] || return 1
    px_string_has_control_character "$value" && return 1
    PX_PLIST_VALUE="$value"
    return 0
}

px_validate_target_executable() {
    local target="$1"
    [ -f "$target" ] || return 1
    [ ! -L "$target" ] || return 1
    [ -x "$target" ] || return 1
    px_stat_snapshot "$target" PX_TARGET_CANDIDATE || return 1
    px_owner_is_app_trusted "$PX_TARGET_CANDIDATE_UID" || return 1
    px_mode_is_safe_executable "$PX_TARGET_CANDIDATE_MODE" || return 1
    [ "$PX_TARGET_CANDIDATE_LINKS" -eq 1 ] || return 1
    [ "$PX_TARGET_CANDIDATE_SIZE" -gt 0 ] || return 1
    return 0
}

px_consider_app_bundle() {
    local app_dir="$1"
    local bundle_id="$2"
    local is_system="$3"
    px_validate_app_directory "$app_dir" || return 1
    local info_plist="$app_dir/Info.plist"
    px_validate_info_plist "$info_plist" || return 1
    px_read_info_value "$info_plist" CFBundleIdentifier || return 1
    local found_bundle_id="$PX_PLIST_VALUE"
    [ "$found_bundle_id" = "$bundle_id" ] || return 1
    px_read_info_value "$info_plist" CFBundleExecutable || return 1
    local executable_name="$PX_PLIST_VALUE"
    px_validate_safe_basename "$executable_name" || return 1
    local target="$app_dir/$executable_name"
    px_validate_target_executable "$target" || return 1

    PX_TARGET_PATH="$target"
    PX_TARGET_APP_BUNDLE="$app_dir"
    PX_TARGET_IS_SYSTEM="$is_system"
    PX_TARGET_DEVICE="$PX_TARGET_CANDIDATE_DEVICE"
    PX_TARGET_INODE="$PX_TARGET_CANDIDATE_INODE"
    PX_TARGET_UID="$PX_TARGET_CANDIDATE_UID"
    PX_TARGET_GID="$PX_TARGET_CANDIDATE_GID"
    PX_TARGET_MODE="$PX_TARGET_CANDIDATE_MODE"
    PX_TARGET_SIZE="$PX_TARGET_CANDIDATE_SIZE"
    PX_TARGET_LINKS="$PX_TARGET_CANDIDATE_LINKS"
    PX_TARGET_MTIME="$PX_TARGET_CANDIDATE_MTIME"
    PX_TARGET_CTIME="$PX_TARGET_CANDIDATE_CTIME"
    return 0
}

find_app_executable() {
    local bundle_id="$1"
    px_validate_bundle_id "$bundle_id" || return 1
    PX_TARGET_PATH=""
    local raw_root root app_dir uuid_dir
    local system_roots=(
        "/Applications"
        "/var/jb/Applications"
        "/private/preboot/jb/Applications"
    )
    for raw_root in "${system_roots[@]}"; do
        [ -e "$raw_root" ] || continue
        px_physical_directory "$raw_root" || continue
        root="$PX_PHYSICAL_DIRECTORY"
        px_validate_app_directory "$root" || continue
        for app_dir in "$root"/*.app; do
            [ -d "$app_dir" ] || continue
            [ ! -L "$app_dir" ] || continue
            px_consider_app_bundle "$app_dir" "$bundle_id" 1 && return 0
        done
    done

    local bundle_roots=(
        "/var/containers/Bundle/Application"
        "/var/mobile/Containers/Bundle/Application"
        "/private/var/containers/Bundle/Application"
    )
    for raw_root in "${bundle_roots[@]}"; do
        [ -e "$raw_root" ] || continue
        px_physical_directory "$raw_root" || continue
        root="$PX_PHYSICAL_DIRECTORY"
        px_validate_app_directory "$root" || continue
        for uuid_dir in "$root"/*; do
            [ -d "$uuid_dir" ] || continue
            [ ! -L "$uuid_dir" ] || continue
            px_validate_app_directory "$uuid_dir" || continue
            for app_dir in "$uuid_dir"/*.app; do
                [ -d "$app_dir" ] || continue
                [ ! -L "$app_dir" ] || continue
                px_consider_app_bundle "$app_dir" "$bundle_id" 0 && return 0
            done
        done
    done
    return 1
}

px_validate_target_unchanged() {
    [ -n "$PX_TARGET_PATH" ] || return 1
    px_validate_target_executable "$PX_TARGET_PATH" || return 1
    [ "$PX_TARGET_CANDIDATE_DEVICE" = "$PX_TARGET_DEVICE" ] || return 1
    [ "$PX_TARGET_CANDIDATE_INODE" = "$PX_TARGET_INODE" ] || return 1
    [ "$PX_TARGET_CANDIDATE_UID" = "$PX_TARGET_UID" ] || return 1
    [ "$PX_TARGET_CANDIDATE_GID" = "$PX_TARGET_GID" ] || return 1
    [ "$PX_TARGET_CANDIDATE_MODE" = "$PX_TARGET_MODE" ] || return 1
    [ "$PX_TARGET_CANDIDATE_SIZE" = "$PX_TARGET_SIZE" ] || return 1
    [ "$PX_TARGET_CANDIDATE_LINKS" = "$PX_TARGET_LINKS" ] || return 1
    [ "$PX_TARGET_CANDIDATE_MTIME" = "$PX_TARGET_MTIME" ] || return 1
    [ "$PX_TARGET_CANDIDATE_CTIME" = "$PX_TARGET_CTIME" ] || return 1
    return 0
}

# === Extract entitlements from app ===
extract_entitlements() {
    local app_binary="$1"
    local output_file="$2"
    [ "$app_binary" = "$PX_TARGET_PATH" ] || return "$PX_KEYCHAIN_EXIT_TARGET_UNAVAILABLE"
    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_workspace_child_path app_ent.xml || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    [ "$output_file" = "$PX_WORKSPACE_CHILD_PATH" ] || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    [ ! -e "$output_file" ] && [ ! -L "$output_file" ] || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_validate_target_unchanged || return "$PX_KEYCHAIN_EXIT_TARGET_UNAVAILABLE"
    px_stat_snapshot "$app_binary" PX_TARGET_EXTRACT_BEFORE || return "$PX_KEYCHAIN_EXIT_TARGET_UNAVAILABLE"

    "$PX_LDID_PATH" -e "$app_binary" > "$output_file" 2>/dev/null
    local extract_status=$?

    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_stat_snapshot "$app_binary" PX_TARGET_EXTRACT_AFTER || return "$PX_KEYCHAIN_EXIT_TARGET_UNAVAILABLE"
    px_same_complete_snapshot PX_TARGET_EXTRACT_BEFORE PX_TARGET_EXTRACT_AFTER || return "$PX_KEYCHAIN_EXIT_TARGET_UNAVAILABLE"
    [ "$extract_status" -eq 0 ] || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
    "$PX_CHMOD_PATH" 600 "$output_file" >/dev/null 2>&1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_validate_workspace_file "$output_file" 600 0 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    PX_APP_ENT_PATH="$output_file"
    return "$PX_KEYCHAIN_EXIT_COMPLETED"
}

# === Canonical Keychain access-group authority ===
PX_CANONICAL_GROUP_CSV=""

px_group_value_is_valid() {
    local group="$1"
    [ -n "$group" ] || return 1
    [ "${#group}" -le 512 ] || return 1
    px_string_has_control_character "$group" && return 1
    case "$group" in *,*) return 1 ;; esac
    local trimmed
    trimmed=$(printf '%s' "$group" | "$PX_SED_PATH" 's/^ *//;s/ *$//') || return 1
    [ "$trimmed" = "$group" ] || return 1
    return 0
}

px_group_csv_contains() {
    local csv="$1"
    local group="$2"
    [ -n "$csv" ] || return 1
    case ",$csv," in
        *",$group,"*) return 0 ;;
        *) return 1 ;;
    esac
}

px_canonicalize_group_csv() {
    local input="$1"
    PX_CANONICAL_GROUP_CSV=""
    [ -n "$input" ] || return 1
    [ "${#input}" -le 8192 ] || return 1
    px_string_has_control_character "$input" && return 1
    case "$input" in ,*|*,|*,,*) return 1 ;; esac
    local parts=()
    IFS=',' read -ra parts <<< "$input"
    [ "${#parts[@]}" -gt 0 ] && [ "${#parts[@]}" -le 128 ] || return 1
    local part group result="" count=0
    for part in "${parts[@]}"; do
        group=$(printf '%s' "$part" | "$PX_SED_PATH" 's/^ *//;s/ *$//') || return 1
        px_group_value_is_valid "$group" || return 1
        if ! px_group_csv_contains "$result" "$group"; then
            count=$((count + 1))
            [ "$count" -le 128 ] || return 1
            if [ -n "$result" ]; then result="$result,$group"; else result="$group"; fi
            [ "${#result}" -le 8192 ] || return 1
        fi
    done
    [ -n "$result" ] || return 1
    PX_CANONICAL_GROUP_CSV="$result"
    return 0
}

px_add_group_to_canonical_csv() {
    local csv="$1"
    local group="$2"
    PX_CANONICAL_GROUP_CSV=""
    px_group_value_is_valid "$group" || return 1
    if [ -z "$csv" ]; then
        PX_CANONICAL_GROUP_CSV="$group"
        return 0
    fi
    px_canonicalize_group_csv "$csv" || return 1
    local result="$PX_CANONICAL_GROUP_CSV"
    if ! px_group_csv_contains "$result" "$group"; then
        result="$result,$group"
        [ "${#result}" -le 8192 ] || return 1
        local entries=()
        IFS=',' read -ra entries <<< "$result"
        [ "${#entries[@]}" -le 128 ] || return 1
    fi
    PX_CANONICAL_GROUP_CSV="$result"
    return 0
}

px_group_csv_is_subset() {
    local requested="$1"
    local effective="$2"
    px_canonicalize_group_csv "$requested" || return 1
    local canonical_requested="$PX_CANONICAL_GROUP_CSV"
    px_canonicalize_group_csv "$effective" || return 1
    local canonical_effective="$PX_CANONICAL_GROUP_CSV"
    local groups=() group
    IFS=',' read -ra groups <<< "$canonical_requested"
    for group in "${groups[@]}"; do
        px_group_csv_contains "$canonical_effective" "$group" || return 1
    done
    return 0
}

# === Parse keychain access groups from entitlements ===
parse_keychain_groups() {
    local ent_file="$1"
    px_validate_workspace_file "$ent_file" 600 0 1 || return 1
    px_stat_snapshot "$ent_file" PX_PARSE_GROUPS_BEFORE || return 1
    local groups=""
    local in_groups=0
    local line group group_count=0
    while IFS= read -r line; do
        if printf '%s' "$line" | "$PX_GREP_PATH" -q "keychain-access-groups"; then
            in_groups=1
            continue
        fi
        if [ "$in_groups" -eq 1 ]; then
            if printf '%s' "$line" | "$PX_GREP_PATH" -q "</array>"; then
                in_groups=0
                continue
            fi
            if printf '%s' "$line" | "$PX_GREP_PATH" -q "<string>"; then
                group=$(printf '%s' "$line" | "$PX_SED_PATH" -n 's/.*<string>\(.*\)<\/string>.*/\1/p')
                px_group_value_is_valid "$group" || return 1
                group_count=$((group_count + 1))
                [ "$group_count" -le 128 ] || return 1
                if [ -n "$groups" ]; then groups="$groups,$group"; else groups="$group"; fi
                [ "${#groups}" -le 8192 ] || return 1
            fi
        fi
    done < "$ent_file"
    px_stat_snapshot "$ent_file" PX_PARSE_GROUPS_AFTER || return 1
    px_same_complete_snapshot PX_PARSE_GROUPS_BEFORE PX_PARSE_GROUPS_AFTER || return 1
    printf '%s\n' "$groups"
}

# === Parse application-identifier from entitlements ===
parse_app_identifier() {
    local ent_file="$1"
    px_validate_workspace_file "$ent_file" 600 0 1 || return 1
    px_stat_snapshot "$ent_file" PX_PARSE_IDENTIFIER_BEFORE || return 1
    local identifier=""
    local found_key=0
    local line
    while IFS= read -r line; do
        if printf '%s' "$line" | "$PX_GREP_PATH" -q "application-identifier"; then
            found_key=1
            continue
        fi
        if [ "$found_key" -eq 1 ] && printf '%s' "$line" | "$PX_GREP_PATH" -q "<string>"; then
            identifier=$(printf '%s' "$line" | "$PX_SED_PATH" -n 's/.*<string>\(.*\)<\/string>.*/\1/p')
            break
        fi
    done < "$ent_file"
    px_stat_snapshot "$ent_file" PX_PARSE_IDENTIFIER_AFTER || return 1
    px_same_complete_snapshot PX_PARSE_IDENTIFIER_BEFORE PX_PARSE_IDENTIFIER_AFTER || return 1
    [ "${#identifier}" -le 4096 ] || return 1
    px_string_has_control_character "$identifier" && return 1
    printf '%s\n' "$identifier"
}

# === Ensure a group exists in a CSV list ===
ensure_group_in_csv() {
    local csv="$1"
    local group="$2"
    if [ -z "$group" ]; then
        echo "$csv"
        return 0
    fi
    # Normalize: remove any surrounding whitespace
    group="$(echo "$group" | "$PX_SED_PATH" 's/^ *//;s/ *$//')"
    if [ -z "$group" ]; then
        echo "$csv"
        return 0
    fi
    if [ -z "$csv" ]; then
        echo "$group"
        return 0
    fi
    case ",$csv," in
        *",$group,"*) echo "$csv" ;;
        *) echo "$csv,$group" ;;
    esac
}

# === Generate entitlements plist for helper tool ===
# For system apps, copy the accepted entitlement snapshot and retain existing policy.
generate_helper_entitlements() {
    local keychain_groups="$1"
    local app_groups="$2"
    local output_file="$3"
    local app_identifier="$4"
    local source_ent_file="$5"

    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_require_workspace_child_absent helper_ent.plist || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    [ "$output_file" = "$PX_WORKSPACE_CHILD_PATH" ] || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    [ "${#keychain_groups}" -le 65536 ] || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
    [ "${#app_groups}" -le 65536 ] || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
    [ "${#app_identifier}" -le 4096 ] || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
    px_string_has_control_character "$keychain_groups" && return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
    px_string_has_control_character "$app_groups" && return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
    px_string_has_control_character "$app_identifier" && return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"

    if [ -n "$source_ent_file" ]; then
        [ "$source_ent_file" = "$PX_APP_ENT_PATH" ] || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
        px_validate_workspace_file "$source_ent_file" 600 0 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
        px_stat_snapshot "$source_ent_file" PX_SOURCE_ENT_BEFORE || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
        "$PX_CP_PATH" "$source_ent_file" "$output_file" || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
        px_stat_snapshot "$source_ent_file" PX_SOURCE_ENT_AFTER || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
        px_same_complete_snapshot PX_SOURCE_ENT_BEFORE PX_SOURCE_ENT_AFTER || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
        "$PX_CMP_PATH" "$source_ent_file" "$output_file" >/dev/null 2>&1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
        "$PX_CHMOD_PATH" 600 "$output_file" >/dev/null 2>&1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
        px_validate_workspace_file "$output_file" 600 0 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"

        "$PX_PLUTIL_PATH" -replace "com.apple.private.security.no-sandbox" -bool true "$output_file" 2>/dev/null || true
        "$PX_PLUTIL_PATH" -replace "com.apple.private.security.no-container" -bool true "$output_file" 2>/dev/null || true
        "$PX_PLUTIL_PATH" -replace "com.apple.private.security.container-required" -bool false "$output_file" 2>/dev/null || true
    else
        {
            printf '<?xml version="1.0" encoding="UTF-8"?>\n'
            printf '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
            printf '<plist version="1.0">\n'
            printf '<dict>\n'
            printf '    <key>platform-application</key>\n'
            printf '    <true/>\n'
            if [ -n "$app_identifier" ]; then
                printf '    <key>application-identifier</key>\n'
                printf '    <string>%s</string>\n' "$app_identifier"
            fi
            printf '    <key>com.apple.private.security.no-sandbox</key>\n'
            printf '    <true/>\n'
            printf '    <key>com.apple.private.security.no-container</key>\n'
            printf '    <true/>\n'
            printf '    <key>com.apple.private.security.container-required</key>\n'
            printf '    <false/>\n'
            printf '    <key>com.apple.keystore.access-keychain-keys</key>\n'
            printf '    <true/>\n'
            printf '    <key>com.apple.keystore.device</key>\n'
            printf '    <true/>\n'
            if [ -n "$keychain_groups" ]; then
                printf '    <key>keychain-access-groups</key>\n'
                printf '    <array>\n'
                IFS=',' read -ra GROUPS <<< "$keychain_groups"
                local group
                for group in "${GROUPS[@]}"; do
                    printf '        <string>%s</string>\n' "$group"
                done
                printf '    </array>\n'
            fi
            if [ -n "$app_groups" ]; then
                printf '    <key>com.apple.security.application-groups</key>\n'
                printf '    <array>\n'
                IFS=',' read -ra GROUPS <<< "$app_groups"
                local group
                for group in "${GROUPS[@]}"; do
                    printf '        <string>%s</string>\n' "$group"
                done
                printf '    </array>\n'
            fi
            printf '</dict>\n'
            printf '</plist>\n'
        } > "$output_file" || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
    fi

    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    [ -f "$output_file" ] && [ ! -L "$output_file" ] || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    "$PX_CHMOD_PATH" 600 "$output_file" >/dev/null 2>&1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_validate_workspace_file "$output_file" 600 0 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    PX_HELPER_ENT_PATH="$output_file"
    return "$PX_KEYCHAIN_EXIT_COMPLETED"
}

# === Parse application groups from the accepted entitlement snapshot ===
parse_app_groups() {
    local ent_file="$1"
    px_validate_workspace_file "$ent_file" 600 0 1 || return 1
    px_stat_snapshot "$ent_file" PX_PARSE_APP_GROUPS_BEFORE || return 1
    local groups=""
    local in_groups=0
    local line group
    while IFS= read -r line; do
        if printf '%s' "$line" | "$PX_GREP_PATH" -q "com.apple.security.application-groups"; then
            in_groups=1
            continue
        fi
        if [ "$in_groups" -eq 1 ]; then
            if printf '%s' "$line" | "$PX_GREP_PATH" -q "</array>"; then
                in_groups=0
                continue
            fi
            if printf '%s' "$line" | "$PX_GREP_PATH" -q "<string>"; then
                group=$(printf '%s' "$line" | "$PX_SED_PATH" -n 's/.*<string>\(.*\)<\/string>.*/\1/p')
                if [ -n "$group" ]; then
                    if [ -n "$groups" ]; then groups="$groups,$group"; else groups="$group"; fi
                fi
            fi
        fi
    done < "$ent_file"
    px_stat_snapshot "$ent_file" PX_PARSE_APP_GROUPS_AFTER || return 1
    px_same_complete_snapshot PX_PARSE_APP_GROUPS_BEFORE PX_PARSE_APP_GROUPS_AFTER || return 1
    [ "${#groups}" -le 65536 ] || return 1
    px_string_has_control_character "$groups" && return 1
    printf '%s\n' "$groups"
}

px_prepare_working_helper() {
    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_require_workspace_child_absent backup_helper || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    local destination="$PX_WORKSPACE_CHILD_PATH"
    px_stat_snapshot "$PX_INSTALLED_HELPER_PATH" PX_HELPER_SOURCE_BEFORE || return "$PX_KEYCHAIN_EXIT_HELPER_UNAVAILABLE"
    px_same_complete_snapshot PX_INSTALLED_HELPER PX_HELPER_SOURCE_BEFORE || return "$PX_KEYCHAIN_EXIT_HELPER_UNAVAILABLE"
    "$PX_CP_PATH" "$PX_INSTALLED_HELPER_PATH" "$destination" || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_stat_snapshot "$PX_INSTALLED_HELPER_PATH" PX_HELPER_SOURCE_AFTER || return "$PX_KEYCHAIN_EXIT_HELPER_UNAVAILABLE"
    px_same_complete_snapshot PX_HELPER_SOURCE_BEFORE PX_HELPER_SOURCE_AFTER || return "$PX_KEYCHAIN_EXIT_HELPER_UNAVAILABLE"
    "$PX_CMP_PATH" "$PX_INSTALLED_HELPER_PATH" "$destination" >/dev/null 2>&1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    "$PX_CHMOD_PATH" 700 "$destination" >/dev/null 2>&1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_validate_workspace_file "$destination" 700 1 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    PX_WORKING_HELPER_PATH="$destination"
    return "$PX_KEYCHAIN_EXIT_COMPLETED"
}

# === Resign the private working helper only ===
resign_helper() {
    local ent_file="$1"
    local binary_path="$2"
    [ "$ent_file" = "$PX_HELPER_ENT_PATH" ] || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    [ "$binary_path" = "$PX_WORKING_HELPER_PATH" ] || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_validate_workspace_file "$ent_file" 600 0 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_validate_workspace_file "$binary_path" 700 1 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_stat_snapshot "$ent_file" PX_SIGN_ENT_BEFORE || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_stat_snapshot "$binary_path" PX_SIGN_HELPER_BEFORE || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"

    "$PX_LDID_PATH" -S"$ent_file" "$binary_path" >/dev/null 2>&1
    local sign_status=$?
    [ "$sign_status" -eq 0 ] || return "$PX_KEYCHAIN_EXIT_SIGNING_FAILURE"

    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_stat_snapshot "$ent_file" PX_SIGN_ENT_AFTER || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_same_complete_snapshot PX_SIGN_ENT_BEFORE PX_SIGN_ENT_AFTER || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    [ -f "$binary_path" ] && [ ! -L "$binary_path" ] || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    "$PX_CHMOD_PATH" 700 "$binary_path" >/dev/null 2>&1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_validate_workspace_file "$binary_path" 700 1 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    return "$PX_KEYCHAIN_EXIT_COMPLETED"
}

px_prepare_restore_snapshot() {
    local source_path="$1"
    px_canonicalize_existing_file "$source_path" || return "$PX_KEYCHAIN_EXIT_INVALID_INPUT"
    local canonical_source="$PX_CANONICAL_PATH"
    local canonical_parent="$PX_CANONICAL_PARENT_PATH"
    px_stat_snapshot "$canonical_source" PX_RESTORE_SOURCE_BEFORE || return "$PX_KEYCHAIN_EXIT_INVALID_INPUT"
    px_stat_snapshot "$canonical_parent" PX_RESTORE_PARENT_BEFORE || return "$PX_KEYCHAIN_EXIT_INVALID_INPUT"
    px_require_workspace_child_absent restore_input.plist || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    local snapshot="$PX_WORKSPACE_CHILD_PATH"
    "$PX_CP_PATH" "$canonical_source" "$snapshot" || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_stat_snapshot "$canonical_source" PX_RESTORE_SOURCE_AFTER || return "$PX_KEYCHAIN_EXIT_INVALID_INPUT"
    px_stat_snapshot "$canonical_parent" PX_RESTORE_PARENT_AFTER || return "$PX_KEYCHAIN_EXIT_INVALID_INPUT"
    px_same_complete_snapshot PX_RESTORE_SOURCE_BEFORE PX_RESTORE_SOURCE_AFTER || return "$PX_KEYCHAIN_EXIT_INVALID_INPUT"
    px_same_identity PX_RESTORE_PARENT_BEFORE PX_RESTORE_PARENT_AFTER || return "$PX_KEYCHAIN_EXIT_INVALID_INPUT"
    "$PX_CMP_PATH" "$canonical_source" "$snapshot" >/dev/null 2>&1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    "$PX_CHMOD_PATH" 600 "$snapshot" >/dev/null 2>&1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_validate_workspace_file "$snapshot" 600 0 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    PX_RESTORE_INPUT_PATH="$snapshot"
    return "$PX_KEYCHAIN_EXIT_COMPLETED"
}

px_prepare_backup_output() {
    local output_path="$1"
    px_canonicalize_output_path "$output_path" || return "$PX_KEYCHAIN_EXIT_INVALID_INPUT"
    PX_BACKUP_OUTPUT_PATH="$PX_CANONICAL_OUTPUT_PATH"
    PX_BACKUP_OUTPUT_PARENT="$PX_CANONICAL_OUTPUT_PARENT"
    PX_BACKUP_PARENT_DEVICE="$PX_OUTPUT_PARENT_INITIAL_DEVICE"
    PX_BACKUP_PARENT_INODE="$PX_OUTPUT_PARENT_INITIAL_INODE"
    PX_BACKUP_PARENT_UID="$PX_OUTPUT_PARENT_INITIAL_UID"
    PX_BACKUP_PARENT_GID="$PX_OUTPUT_PARENT_INITIAL_GID"
    PX_BACKUP_PARENT_MODE="$PX_OUTPUT_PARENT_INITIAL_MODE"
    PX_BACKUP_PARENT_LINKS="$PX_OUTPUT_PARENT_INITIAL_LINKS"
    if [ "$PX_BACKUP_OUTPUT_EXISTED" -eq 1 ]; then
        PX_BACKUP_FILE_DEVICE="$PX_OUTPUT_FILE_INITIAL_DEVICE"
        PX_BACKUP_FILE_INODE="$PX_OUTPUT_FILE_INITIAL_INODE"
        PX_BACKUP_FILE_UID="$PX_OUTPUT_FILE_INITIAL_UID"
        PX_BACKUP_FILE_GID="$PX_OUTPUT_FILE_INITIAL_GID"
        PX_BACKUP_FILE_MODE="$PX_OUTPUT_FILE_INITIAL_MODE"
        PX_BACKUP_FILE_SIZE="$PX_OUTPUT_FILE_INITIAL_SIZE"
        PX_BACKUP_FILE_LINKS="$PX_OUTPUT_FILE_INITIAL_LINKS"
        PX_BACKUP_FILE_MTIME="$PX_OUTPUT_FILE_INITIAL_MTIME"
        PX_BACKUP_FILE_CTIME="$PX_OUTPUT_FILE_INITIAL_CTIME"
    fi
    return "$PX_KEYCHAIN_EXIT_COMPLETED"
}

px_backup_parent_is_unchanged() {
    [ -d "$PX_BACKUP_OUTPUT_PARENT" ] || return 1
    [ -w "$PX_BACKUP_OUTPUT_PARENT" ] || return 1
    px_stat_snapshot "$PX_BACKUP_OUTPUT_PARENT" PX_BACKUP_PARENT_LIVE || return 1
    [ "$PX_BACKUP_PARENT_LIVE_DEVICE" = "$PX_BACKUP_PARENT_DEVICE" ] || return 1
    [ "$PX_BACKUP_PARENT_LIVE_INODE" = "$PX_BACKUP_PARENT_INODE" ] || return 1
    [ "$PX_BACKUP_PARENT_LIVE_UID" = "$PX_BACKUP_PARENT_UID" ] || return 1
    [ "$PX_BACKUP_PARENT_LIVE_GID" = "$PX_BACKUP_PARENT_GID" ] || return 1
    [ "$PX_BACKUP_PARENT_LIVE_MODE" = "$PX_BACKUP_PARENT_MODE" ] || return 1
    [ "$PX_BACKUP_PARENT_LIVE_LINKS" = "$PX_BACKUP_PARENT_LINKS" ] || return 1
    return 0
}

px_revalidate_backup_output_before_execution() {
    px_backup_parent_is_unchanged || return 1
    [ ! -L "$PX_BACKUP_OUTPUT_PATH" ] || return 1
    if [ "$PX_BACKUP_OUTPUT_EXISTED" -eq 1 ]; then
        [ -f "$PX_BACKUP_OUTPUT_PATH" ] || return 1
        px_stat_snapshot "$PX_BACKUP_OUTPUT_PATH" PX_BACKUP_FILE_LIVE || return 1
        [ "$PX_BACKUP_FILE_LIVE_DEVICE" = "$PX_BACKUP_FILE_DEVICE" ] || return 1
        [ "$PX_BACKUP_FILE_LIVE_INODE" = "$PX_BACKUP_FILE_INODE" ] || return 1
        [ "$PX_BACKUP_FILE_LIVE_UID" = "$PX_BACKUP_FILE_UID" ] || return 1
        [ "$PX_BACKUP_FILE_LIVE_GID" = "$PX_BACKUP_FILE_GID" ] || return 1
        [ "$PX_BACKUP_FILE_LIVE_MODE" = "$PX_BACKUP_FILE_MODE" ] || return 1
        [ "$PX_BACKUP_FILE_LIVE_SIZE" = "$PX_BACKUP_FILE_SIZE" ] || return 1
        [ "$PX_BACKUP_FILE_LIVE_LINKS" = "$PX_BACKUP_FILE_LINKS" ] || return 1
        [ "$PX_BACKUP_FILE_LIVE_MTIME" = "$PX_BACKUP_FILE_MTIME" ] || return 1
        [ "$PX_BACKUP_FILE_LIVE_CTIME" = "$PX_BACKUP_FILE_CTIME" ] || return 1
    else
        [ ! -e "$PX_BACKUP_OUTPUT_PATH" ] || return 1
    fi
    return 0
}

px_validate_backup_output_after_execution() {
    local raw_status="$1"
    px_backup_parent_is_unchanged || return 1
    [ ! -L "$PX_BACKUP_OUTPUT_PATH" ] || return 1
    if [ -e "$PX_BACKUP_OUTPUT_PATH" ]; then
        [ -f "$PX_BACKUP_OUTPUT_PATH" ] || return 1
        px_stat_snapshot "$PX_BACKUP_OUTPUT_PATH" PX_BACKUP_OUTPUT_AFTER || return 1
        if [ "$raw_status" -eq "$PX_KEYCHAIN_EXIT_COMPLETED" ] ||
           [ "$raw_status" -eq "$PX_KEYCHAIN_EXIT_PARTIAL" ]; then
            [ "$PX_BACKUP_OUTPUT_AFTER_SIZE" -gt 0 ] || return 1
        fi
    elif [ "$raw_status" -eq "$PX_KEYCHAIN_EXIT_COMPLETED" ] ||
         [ "$raw_status" -eq "$PX_KEYCHAIN_EXIT_PARTIAL" ]; then
        return 1
    fi
    return 0
}

px_validate_helper_execution() {
    px_validate_workspace_identity || return 1
    [ -n "$PX_HELPER_ENT_PATH" ] || return 1
    [ -n "$PX_WORKING_HELPER_PATH" ] || return 1
    [ -n "$PX_EFFECTIVE_ENT_PATH" ] || return 1
    [ "$PX_EFFECTIVE_ENT_PATH" = "$PX_SIGNED_HELPER_ENT_PATH" ] || return 1
    px_validate_workspace_file "$PX_HELPER_ENT_PATH" 600 0 1 || return 1
    px_validate_workspace_file "$PX_WORKING_HELPER_PATH" 700 1 1 || return 1
    px_validate_workspace_file "$PX_EFFECTIVE_ENT_PATH" 600 0 1 || return 1
    px_stat_snapshot "$PX_HELPER_ENT_PATH" PX_HELPER_ENT_LIVE || return 1
    px_same_complete_snapshot PX_HELPER_ENT_AUTHORITY PX_HELPER_ENT_LIVE || return 1
    px_stat_snapshot "$PX_WORKING_HELPER_PATH" PX_SIGNED_HELPER_LIVE || return 1
    px_same_complete_snapshot PX_SIGNED_HELPER_AUTHORITY PX_SIGNED_HELPER_LIVE || return 1
    px_stat_snapshot "$PX_EFFECTIVE_ENT_PATH" PX_EFFECTIVE_LIVE || return 1
    px_same_complete_snapshot PX_EFFECTIVE_AUTHORITY PX_EFFECTIVE_LIVE || return 1
    return 0
}

# === Main functions ===
px_prepare_target_context() {
    local bundle_id="$1"
    find_app_executable "$bundle_id" || return "$PX_KEYCHAIN_EXIT_TARGET_UNAVAILABLE"
    local ent_file="$PX_WORKSPACE_PATH/app_ent.xml"
    extract_entitlements "$PX_TARGET_PATH" "$ent_file"
    return $?
}

px_select_source_entitlement() {
    local app_identifier="$1"
    PX_SOURCE_ENT_FOR_SYSTEM=""
    if [ "$PX_TARGET_IS_SYSTEM" -eq 1 ]; then
        PX_SOURCE_ENT_FOR_SYSTEM="$PX_APP_ENT_PATH"
    else
        case "$app_identifier" in
            com.apple.*) PX_SOURCE_ENT_FOR_SYSTEM="$PX_APP_ENT_PATH" ;;
        esac
    fi
}

px_prepare_requested_groups() {
    local bundle_id="$1"
    local source_groups selected_groups app_identifier app_groups
    source_groups=$(parse_keychain_groups "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"

    if [ "$OVERRIDE_KEYCHAIN_GROUPS_PRESENT" -eq 1 ]; then
        px_canonicalize_group_csv "$OVERRIDE_KEYCHAIN_GROUPS" || return "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
        selected_groups="$PX_CANONICAL_GROUP_CSV"
        log_info "Using caller-selected keychain groups"
    elif [ -n "$source_groups" ]; then
        px_canonicalize_group_csv "$source_groups" || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
        selected_groups="$PX_CANONICAL_GROUP_CSV"
    else
        selected_groups=""
    fi

    app_identifier=$(parse_app_identifier "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    if [ -z "$app_identifier" ]; then
        app_identifier="$bundle_id"
    fi
    px_group_value_is_valid "$app_identifier" || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
    px_add_group_to_canonical_csv "$selected_groups" "$app_identifier" || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
    PX_REQUESTED_GROUPS_CSV="$PX_CANONICAL_GROUP_CSV"
    [ -n "$PX_REQUESTED_GROUPS_CSV" ] || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"

    app_groups=$(parse_app_groups "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    PX_APP_IDENTIFIER="$app_identifier"
    PX_APP_GROUPS_CSV="$app_groups"
    px_select_source_entitlement "$app_identifier"
    log_info "Requested groups validated"
    return "$PX_KEYCHAIN_EXIT_COMPLETED"
}

px_extract_signed_helper_entitlements() {
    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_validate_workspace_file "$PX_HELPER_ENT_PATH" 600 0 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_validate_workspace_file "$PX_WORKING_HELPER_PATH" 700 1 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_require_workspace_child_absent signed_helper_ent.plist || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    local signed_ent_file="$PX_WORKSPACE_CHILD_PATH"
    px_stat_snapshot "$PX_WORKING_HELPER_PATH" PX_EFFECTIVE_HELPER_BEFORE || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"

    "$PX_LDID_PATH" -e "$PX_WORKING_HELPER_PATH" > "$signed_ent_file" 2>/dev/null
    local extraction_status=$?

    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_stat_snapshot "$PX_WORKING_HELPER_PATH" PX_EFFECTIVE_HELPER_AFTER || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_same_complete_snapshot PX_EFFECTIVE_HELPER_BEFORE PX_EFFECTIVE_HELPER_AFTER || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_stat_snapshot "$PX_WORKING_HELPER_PATH" PX_SIGNED_HELPER_AUTHORITY || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    [ "$extraction_status" -eq 0 ] || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
    "$PX_CHMOD_PATH" 600 "$signed_ent_file" >/dev/null 2>&1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_validate_workspace_file "$signed_ent_file" 600 0 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"

    local effective_groups
    effective_groups=$(parse_keychain_groups "$signed_ent_file") || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
    [ -n "$effective_groups" ] || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
    px_canonicalize_group_csv "$effective_groups" || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
    PX_EFFECTIVE_GROUPS_CSV="$PX_CANONICAL_GROUP_CSV"
    px_group_csv_is_subset "$PX_REQUESTED_GROUPS_CSV" "$PX_EFFECTIVE_GROUPS_CSV" || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"

    PX_SIGNED_HELPER_ENT_PATH="$signed_ent_file"
    PX_EFFECTIVE_ENT_PATH="$signed_ent_file"
    px_stat_snapshot "$PX_EFFECTIVE_ENT_PATH" PX_EFFECTIVE_AUTHORITY || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    log_info "Signed helper access scope validated"
    return "$PX_KEYCHAIN_EXIT_COMPLETED"
}

px_finish_signed_helper() {
    local helper_ent="$PX_WORKSPACE_PATH/helper_ent.plist"
    generate_helper_entitlements "$PX_REQUESTED_GROUPS_CSV" "$PX_APP_GROUPS_CSV" "$helper_ent" "$PX_APP_IDENTIFIER" "$PX_SOURCE_ENT_FOR_SYSTEM"
    local status=$?
    [ "$status" -eq 0 ] || return "$status"
    px_prepare_working_helper
    status=$?
    [ "$status" -eq 0 ] || return "$status"
    resign_helper "$PX_HELPER_ENT_PATH" "$PX_WORKING_HELPER_PATH"
    status=$?
    [ "$status" -eq 0 ] || return "$status"
    px_stat_snapshot "$PX_HELPER_ENT_PATH" PX_HELPER_ENT_AUTHORITY || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_extract_signed_helper_entitlements
    return $?
}

do_backup() {
    local bundle_id="$1"
    local backup_file="$2"

    log_info "Starting keychain backup"
    px_prepare_backup_output "$backup_file"
    local path_status=$?
    [ "$path_status" -eq 0 ] || return "$path_status"
    px_create_workspace || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"

    log_info "Locating target application..."
    px_prepare_target_context "$bundle_id"
    local context_status=$?
    [ "$context_status" -eq 0 ] || return "$context_status"
    px_prepare_requested_groups "$bundle_id"
    local group_status=$?
    [ "$group_status" -eq 0 ] || return "$group_status"

    log_info "Preparing private signed helper..."
    px_finish_signed_helper
    local helper_status=$?
    [ "$helper_status" -eq 0 ] || return "$helper_status"
    px_validate_helper_execution || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_revalidate_backup_output_before_execution || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"

    local helper_args=(
        "--action" "backup"
        "--file" "$PX_BACKUP_OUTPUT_PATH"
        "--groups" "$PX_REQUESTED_GROUPS_CSV"
        "--requested-groups" "$PX_REQUESTED_GROUPS_CSV"
        "--effective-entitlements-file" "$PX_EFFECTIVE_ENT_PATH"
    )
    if [ "$VERBOSE" -eq 1 ]; then helper_args+=("--verbose"); fi
    "$PX_WORKING_HELPER_PATH" "${helper_args[@]}"
    local raw_exit_code=$?

    px_validate_helper_execution || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_validate_backup_output_after_execution "$raw_exit_code" || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    normalize_helper_exit_status "$raw_exit_code"
    local exit_code=$?
    if [ "$exit_code" -eq "$PX_KEYCHAIN_EXIT_COMPLETED" ]; then
        log_info "Backup completed successfully"
    else
        log_error "Backup failed with exit code: $exit_code"
    fi
    return "$exit_code"
}

do_restore() {
    local bundle_id="$1"
    local restore_file="$2"
    local overwrite="$3"

    log_info "Starting keychain restore"
    px_create_workspace || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_prepare_restore_snapshot "$restore_file"
    local snapshot_status=$?
    [ "$snapshot_status" -eq 0 ] || return "$snapshot_status"

    log_info "Locating target application..."
    px_prepare_target_context "$bundle_id"
    local context_status=$?
    [ "$context_status" -eq 0 ] || return "$context_status"
    px_prepare_requested_groups "$bundle_id"
    local group_status=$?
    [ "$group_status" -eq 0 ] || return "$group_status"

    log_info "Preparing private signed helper..."
    px_finish_signed_helper
    local helper_status=$?
    [ "$helper_status" -eq 0 ] || return "$helper_status"
    px_validate_helper_execution || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_validate_workspace_file "$PX_RESTORE_INPUT_PATH" 600 0 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"

    local helper_args=(
        "--action" "restore"
        "--file" "$PX_RESTORE_INPUT_PATH"
        "--requested-groups" "$PX_REQUESTED_GROUPS_CSV"
        "--effective-entitlements-file" "$PX_EFFECTIVE_ENT_PATH"
    )
    if [ "$overwrite" = "--overwrite" ]; then helper_args+=("--overwrite"); fi
    if [ "$VERBOSE" -eq 1 ]; then helper_args+=("--verbose"); fi
    "$PX_WORKING_HELPER_PATH" "${helper_args[@]}"
    local raw_exit_code=$?

    px_validate_helper_execution || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_validate_workspace_file "$PX_RESTORE_INPUT_PATH" 600 0 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    normalize_helper_exit_status "$raw_exit_code"
    local exit_code=$?
    if [ "$exit_code" -eq "$PX_KEYCHAIN_EXIT_COMPLETED" ]; then
        log_info "Restore completed successfully"
    else
        log_error "Restore failed with exit code: $exit_code"
    fi
    return "$exit_code"
}

do_wipe() {
    local bundle_id="$1"

    log_info "Starting keychain wipe"
    px_create_workspace || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_prepare_target_context "$bundle_id"
    local context_status=$?
    [ "$context_status" -eq 0 ] || return "$context_status"
    px_prepare_requested_groups "$bundle_id"
    local group_status=$?
    [ "$group_status" -eq 0 ] || return "$group_status"

    log_warn "This will delete all Keychain items for the selected groups"
    px_finish_signed_helper
    local helper_status=$?
    [ "$helper_status" -eq 0 ] || return "$helper_status"
    px_validate_helper_execution || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"

    local helper_args=(
        "--action" "wipe"
        "--groups" "$PX_REQUESTED_GROUPS_CSV"
        "--requested-groups" "$PX_REQUESTED_GROUPS_CSV"
        "--effective-entitlements-file" "$PX_EFFECTIVE_ENT_PATH"
    )
    if [ "$VERBOSE" -eq 1 ]; then helper_args+=("--verbose"); fi
    "$PX_WORKING_HELPER_PATH" "${helper_args[@]}"
    local raw_exit_code=$?

    px_validate_helper_execution || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    normalize_helper_exit_status "$raw_exit_code"
    return $?
}

do_list() {
    local bundle_id="$1"

    log_info "Listing keychain items"
    px_create_workspace || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    px_prepare_target_context "$bundle_id"
    local context_status=$?
    [ "$context_status" -eq 0 ] || return "$context_status"
    px_prepare_requested_groups "$bundle_id"
    local group_status=$?
    [ "$group_status" -eq 0 ] || return "$group_status"

    px_finish_signed_helper
    local helper_status=$?
    [ "$helper_status" -eq 0 ] || return "$helper_status"
    px_validate_helper_execution || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"

    local helper_args=(
        "--action" "list"
        "--groups" "$PX_REQUESTED_GROUPS_CSV"
        "--requested-groups" "$PX_REQUESTED_GROUPS_CSV"
        "--effective-entitlements-file" "$PX_EFFECTIVE_ENT_PATH"
    )
    if [ "$VERBOSE" -eq 1 ]; then helper_args+=("--verbose"); fi
    "$PX_WORKING_HELPER_PATH" "${helper_args[@]}"
    local raw_exit_code=$?

    px_validate_helper_execution || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
    normalize_helper_exit_status "$raw_exit_code"
    return $?
}

print_usage() {
    echo "Usage: $0 <action> <bundleID> [options]"
    echo ""
    echo "Actions:"
    echo "  backup <bundleID> <backup_file>   Backup keychain to file"
    echo "  restore <bundleID> <backup_file>  Restore keychain from file"
    echo "  wipe <bundleID>                   Delete all keychain items"
    echo "  list <bundleID>                   List keychain items"
    echo ""
    echo "Options:"
    echo "  --groups CSV  Select canonical Keychain access groups"
    echo "  --overwrite   For restore: update one exact existing item in place; never delete"
    echo "  --verbose     Show detailed output"
    echo ""
    echo "Example:"
    echo "  $0 backup com.game.app /var/tmp/game_keychain.plist"
    echo "  $0 restore com.game.app /var/tmp/game_keychain.plist --overwrite"
}

# Initialize the trusted metadata and dependency boundary before external work.
if ! px_initialize_metadata_boundary; then
    log_error "Trusted filesystem metadata utility is unavailable"
    exit "$PX_KEYCHAIN_EXIT_DEPENDENCY_UNAVAILABLE"
fi
if ! px_validate_installed_helper; then
    log_error "Installed Keychain helper failed safety validation"
    exit "$PX_KEYCHAIN_EXIT_HELPER_UNAVAILABLE"
fi
if ! px_resolve_trusted_dependencies; then
    log_error "A required trusted utility is unavailable"
    exit "$PX_KEYCHAIN_EXIT_DEPENDENCY_UNAVAILABLE"
fi

# Parse global options
while [[ "$1" == --* ]]; do
    case "$1" in
        --verbose|-v)
            VERBOSE=1
            shift
            ;;
        --help|-h)
            print_usage
            exit "$PX_KEYCHAIN_EXIT_COMPLETED"
            ;;
        *)
            break
            ;;
    esac
done

# Require at least action and bundle ID
if [ $# -lt 2 ]; then
    print_usage
    exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
fi

ACTION="$1"
BUNDLE_ID="$2"
shift 2

if ! px_validate_bundle_id "$BUNDLE_ID"; then
    log_error "Invalid bundle identifier"
    exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
fi

case "$ACTION" in
    backup)
        if [ -z "$1" ]; then
            log_error "Backup file path required"
            print_usage
            exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
        fi
        shift_file="$1"
        shift
        # Parse optional args after required ones
        while [[ "$1" == --* ]]; do
            case "$1" in
                --groups)
                    if [ "$OVERRIDE_KEYCHAIN_GROUPS_PRESENT" -eq 1 ] || [ $# -lt 2 ] || [[ "$2" == --* ]]; then
                        log_error "Invalid or duplicate --groups option"
                        exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
                    fi
                    OVERRIDE_KEYCHAIN_GROUPS_PRESENT=1
                    OVERRIDE_KEYCHAIN_GROUPS="$2"
                    shift 2
                    ;;
                --groups=*)
                    if [ "$OVERRIDE_KEYCHAIN_GROUPS_PRESENT" -eq 1 ]; then
                        log_error "Duplicate --groups option"
                        exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
                    fi
                    OVERRIDE_KEYCHAIN_GROUPS_PRESENT=1
                    OVERRIDE_KEYCHAIN_GROUPS="${1#*=}"
                    shift 1
                    ;;
                *)
                    break
                    ;;
            esac
        done
        [ $# -eq 0 ] || { log_error "Unexpected backup argument"; exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"; }
        do_backup "$BUNDLE_ID" "$shift_file"
        ;;
    restore)
        if [ -z "$1" ]; then
            log_error "Backup file path required"
            print_usage
            exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
        fi
        shift_file="$1"
        shift
        # Next arg may be --overwrite
        restore_overwrite="$1"
        if [ "$restore_overwrite" = "--overwrite" ]; then
            shift
        else
            restore_overwrite=""
        fi
        while [[ "$1" == --* ]]; do
            case "$1" in
                --groups)
                    if [ "$OVERRIDE_KEYCHAIN_GROUPS_PRESENT" -eq 1 ] || [ $# -lt 2 ] || [[ "$2" == --* ]]; then
                        log_error "Invalid or duplicate --groups option"
                        exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
                    fi
                    OVERRIDE_KEYCHAIN_GROUPS_PRESENT=1
                    OVERRIDE_KEYCHAIN_GROUPS="$2"
                    shift 2
                    ;;
                --groups=*)
                    if [ "$OVERRIDE_KEYCHAIN_GROUPS_PRESENT" -eq 1 ]; then
                        log_error "Duplicate --groups option"
                        exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
                    fi
                    OVERRIDE_KEYCHAIN_GROUPS_PRESENT=1
                    OVERRIDE_KEYCHAIN_GROUPS="${1#*=}"
                    shift 1
                    ;;
                *)
                    break
                    ;;
            esac
        done
        [ $# -eq 0 ] || { log_error "Unexpected restore argument"; exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"; }
        do_restore "$BUNDLE_ID" "$shift_file" "$restore_overwrite"
        ;;
    wipe)
        while [[ "$1" == --* ]]; do
            case "$1" in
                --groups)
                    if [ "$OVERRIDE_KEYCHAIN_GROUPS_PRESENT" -eq 1 ] || [ $# -lt 2 ] || [[ "$2" == --* ]]; then
                        log_error "Invalid or duplicate --groups option"
                        exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
                    fi
                    OVERRIDE_KEYCHAIN_GROUPS_PRESENT=1
                    OVERRIDE_KEYCHAIN_GROUPS="$2"
                    shift 2
                    ;;
                --groups=*)
                    if [ "$OVERRIDE_KEYCHAIN_GROUPS_PRESENT" -eq 1 ]; then
                        log_error "Duplicate --groups option"
                        exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
                    fi
                    OVERRIDE_KEYCHAIN_GROUPS_PRESENT=1
                    OVERRIDE_KEYCHAIN_GROUPS="${1#*=}"
                    shift 1
                    ;;
                *)
                    break
                    ;;
            esac
        done
        [ $# -eq 0 ] || { log_error "Unexpected wipe argument"; exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"; }
        do_wipe "$BUNDLE_ID"
        ;;
    list)
        while [[ "$1" == --* ]]; do
            case "$1" in
                --groups)
                    if [ "$OVERRIDE_KEYCHAIN_GROUPS_PRESENT" -eq 1 ] || [ $# -lt 2 ] || [[ "$2" == --* ]]; then
                        log_error "Invalid or duplicate --groups option"
                        exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
                    fi
                    OVERRIDE_KEYCHAIN_GROUPS_PRESENT=1
                    OVERRIDE_KEYCHAIN_GROUPS="$2"
                    shift 2
                    ;;
                --groups=*)
                    if [ "$OVERRIDE_KEYCHAIN_GROUPS_PRESENT" -eq 1 ]; then
                        log_error "Duplicate --groups option"
                        exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
                    fi
                    OVERRIDE_KEYCHAIN_GROUPS_PRESENT=1
                    OVERRIDE_KEYCHAIN_GROUPS="${1#*=}"
                    shift 1
                    ;;
                *)
                    break
                    ;;
            esac
        done
        [ $# -eq 0 ] || { log_error "Unexpected list argument"; exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"; }
        do_list "$BUNDLE_ID"
        ;;
    *)
        log_error "Unknown action: $ACTION"
        print_usage
        exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
        ;;
esac

exit "$?"
