#!/usr/bin/env bash
#
# audit_native_hooks.sh
#
# Fails if coordinated native symbols are installed via MSHookFunction / %hookf
# outside TLinkIOSTweak/PXNativeHookCoordinator.m.
#
# Usage (from repo root or anywhere):
#   ./scripts/audit_native_hooks.sh
#   bash scripts/audit_native_hooks.sh
#
# Exit codes:
#   0 — no violations
#   1 — one or more install points found outside the coordinator
#   2 — usage / environment error
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TWEAK_DIR="$ROOT/TLinkIOSTweak"
COORDINATOR_NAME="PXNativeHookCoordinator.m"

if [[ ! -d "$TWEAK_DIR" ]]; then
  echo "error: TLinkIOSTweak directory not found at: $TWEAK_DIR" >&2
  exit 2
fi

# Symbols that must only be installed inside PXNativeHookCoordinator.m
SYMBOLS=(
  sysctl
  sysctlbyname
  gethostname
  getifaddrs
  IORegistryEntryCreateCFProperty
  IORegistryEntryCreateCFProperties
  IORegistryEntrySearchCFProperty
  CFCopySystemVersionDictionary
  statfs
  statfs64
  getfsstat
  getfsstat64
  CNCopyCurrentNetworkInfo
  gethostuuid
)

# Build alternation for egrep (longest-first avoids partial confusion in reporting)
IFS=$'\n' SORTED_SYMBOLS=($(printf '%s\n' "${SYMBOLS[@]}" | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2-))
unset IFS
ALT="$(IFS='|'; echo "${SORTED_SYMBOLS[*]}")"

# Prefilter: lines that look like Substrate install points
INSTALL_RE="%hookf|MSHookFunction"

violations=0
report_lines=()

shopt -s nullglob
files=("$TWEAK_DIR"/*.x "$TWEAK_DIR"/*.m)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "error: no .x/.m files under $TWEAK_DIR" >&2
  exit 2
fi

# Silence unused-var if ALT only used for docs / future expansion
: "${ALT}"

for f in "${files[@]}"; do
  base="$(basename "$f")"
  if [[ "$base" == "$COORDINATOR_NAME" ]]; then
    continue
  fi

  # Scan line-by-line for install sites that reference a coordinated symbol.
  # Use grep -nE; ignore exit 1 (no match).
  matches="$(grep -nE "${INSTALL_RE}" "$f" 2>/dev/null || true)"
  if [[ -z "$matches" ]]; then
    continue
  fi

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    lineno="${line%%:*}"
    content="${line#*:}"

    # Only consider MSHookFunction / %hookf lines that mention a coordinated symbol.
    hit_sym=""
    for sym in "${SORTED_SYMBOLS[@]}"; do
      # %hookf second arg is exactly the symbol
      if echo "$content" | grep -qE "%hookf[[:space:]]*\\([^,]+,[[:space:]]*${sym}[[:space:]]*,"; then
        hit_sym="$sym"
        break
      fi
      # MSHookFunction first-arg / line contains symbol as identifier segment
      # (sysctlPtr, hook_sysctl, orig_statfs, IORegistryEntryCreateCFProperty, …)
      # Reject longer-name false positives: require non-identifier char (or start)
      # before symbol, and after symbol either end of identifier suffix or boundary.
      # Specifically disallow a leading [A-Za-z0-9] so fstatfs does not match statfs.
      if echo "$content" | grep -qE "MSHookFunction"; then
        if echo "$content" | grep -qE "(^|[^A-Za-z0-9])${sym}([^A-Za-z0-9]|Ptr|ptr|Sym|sym|Symbol|$)"; then
          hit_sym="$sym"
          break
        fi
        # orig_SYMBOL / hook_SYMBOL / hooked_SYMBOL / replaced_SYMBOL
        if echo "$content" | grep -qE "(^|[^A-Za-z0-9])(orig_|hooked_|hook_|replaced_|new_)${sym}([^A-Za-z0-9]|$)"; then
          hit_sym="$sym"
          break
        fi
      fi
    done

    if [[ -n "$hit_sym" ]]; then
      violations=$((violations + 1))
      report_lines+=("${f}:${lineno}: symbol=${hit_sym}: ${content}")
    fi
  done <<< "$matches"
done

echo "=== audit_native_hooks ==="
echo "scan: $TWEAK_DIR/*.{x,m} (excluding $COORDINATOR_NAME)"
echo "symbols: ${SYMBOLS[*]}"
echo

if [[ "$violations" -eq 0 ]]; then
  echo "OK: no coordinated native symbols installed outside ${COORDINATOR_NAME}"
  exit 0
fi

echo "FAIL: ${violations} install point(s) outside ${COORDINATOR_NAME}:"
echo
printf '%s\n' "${report_lines[@]}"
echo
echo "Move MSHookFunction / %hookf for these symbols into ${COORDINATOR_NAME} (providers only)."
exit 1
