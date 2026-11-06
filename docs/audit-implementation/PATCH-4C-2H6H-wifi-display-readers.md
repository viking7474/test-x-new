# Patch 4C.2H6H — WiFi display snapshot and typed accessors

2026-11-06: user confirms H6G build passes and authorizes continued implementation.
Reviewed all WiFiManager source/header and IdentifierManager WiFi generation,
adoption and display callers, the complete currentValueForIdentifier flow and
its native extraction. Scope is six cache accessors and the manager display
fallback after canonical/sidecar precedence; no source-writer change is included.

## Findings and changes

1. **Medium / P1, confirmed observation defect — separate SSID/BSSID reads.**
   common/IdentifierManager.m, currentValueForIdentifier: read currentSSID and
   currentBSSID in separate calls. A cooperative root replacement between calls
   could format A's SSID with B's BSSID even with H6G's atomic retained slots.
   WiFiManager.cachedWiFiDisplayInfo now captures one retained root/revision,
   copies outside the monitor, then rejects a superseding revision without retry.
   PXIdentifierWiFiDisplay formats both fields from that same snapshot.

   Reproduce by replacing the manager's root between its two legacy getters.
   The native fixtures instead verify the corrected contract: an A snapshot can
   be formatted after the provider's live fields become B, without touching those
   getters; A→B→A and another-thread adoption during copy produce a miss. These
   new native tests await macOS CI; no observed device incidence is claimed.

2. **Medium / P1, confirmed unsafe selector path — malformed autoJoin.**
   common/WiFiManager.m, currentAutoJoinStatus sent boolValue unconditionally.
   A plist array/dictionary/date in that field could raise an unrecognized-selector
   exception. Check availability before conversion; a throwing optional converter
   returns NO. Keep NSNumber, NSString and legacy live-memory bool converters.
   No validation/write/lastError side effect is added to this read.

3. **Medium potential / P1 — object-return contracts.**
   currentSSID/currentBSSID/currentNetworkType/currentWiFiStandard and
   lastConnectionTime returned any nonnil field under NSString/NSDate signatures.
   Consumers using string/date methods could crash on malformed persisted data.
   A shared cache-value helper retains one root, checks root/member types and
   catches optional preparation failure. Valid object identity, empty strings,
   case, custom standards and dates remain unchanged. Invalid strings use nil or
   the existing Infrastructure/802.11ac defaults; invalid dates use a fresh NSDate.
   This fixes malformed inputs; no ordinary valid-artifact crash is asserted.

## Flow and compatibility

The display snapshot is cache-only: it never resolves selection, loads files,
initializes another manager, generates/persists data or changes lastError. It
intentionally permits legacy unacknowledged candidates, as the old display getters
already did. H6G's fixed-target acknowledged hook-cache eligibility is unchanged.
The snapshot is a shallow copy, with per-instance revision checks rather than a
global source/profile receipt.

IdentifierManager uses the new API when present. A nil/malformed/throwing modern
snapshot is unavailable for that observation; it never retries with separate
legacy getters. Optional older providers without the selector retain the legacy
path, including SSID-only fallback. That compatibility path cannot guarantee a
combined observation. The existing scalar sanitizer preserves numeric display
conversion, empty pair formatting and rejection of containers; typed public
accessors themselves now honor their NSString/NSDate return contracts.

Canonical device_ids values and valid wifi_info sidecars still win before the
manager is consulted. RootHide injected processes keep their early captured-view
return and never reach manager fallback. Factory creation and unrelated reader
branches are unchanged. Two WiFi fallback value-log calls disappear with the old
formatting block; no logging, queue, timer, polling or cache storage is added.

Individual property reads are still independent observations across calls; a
caller needing a combined pair must use the snapshot. External in-place mutation
of nested mutable objects/private roots, foreign accessor/selector ABI violations,
ProfileManager thread rules, late adoption of older committed payloads and global
selection/source order remain outside this patch. Guards do not validate wild
pointers or prove arbitrary foreign callee exception ownership.

H6G load/save/adoption/revision protocol, source writer enrollment, WiFi hooks,
CF ownership, installer/ctor/bootstrap, package dependencies and Makefile are
compared unchanged. Both package schemes compile these common manager changes.
Full Patch 4 remains partial and H5S-partial marker is preserved.

## Performance and verification

A manager display fallback adds one shallow dictionary copy and two short monitor
acquisitions, replacing separate field observations. Accessors add bounded type
checks and a helper call without new I/O or dynamic class/selector construction.
Boolean reads add one selector-availability check. Expected cost
is low when uncontended; allocation/latency and actual read frequency have not been
profiled, so no net performance gain is claimed. Copy and formatter/provider work
run outside the monitor. No unbounded retry is introduced on cache turnover.

Native cache fixtures compile eight exact new/updated reader methods alongside
H6G cache bodies. Identifier fixtures compile the exact display helper and complete
production reader body, with optional provider controls. Both fixtures run for
rootful and RootHide, with and without ARC exception cleanup at -O0. Compile-only
NSObject category declarations in the reader fixture provide selector types;
there is no NSObject runtime implementation/hook added.

New cases cover empty/typed/malformed fields, optional bool converters/throws,
fresh date fallback and preserved lastError, cache-only counters, A→B→A and
another-thread copy replacement, unacknowledged display compatibility, modern
snapshot failure without legacy retry, numeric/SSID-only/empty formatting,
provider changes and disk/canonical precedence. Existing legacy-provider and
RootHide injected-reader matrices remain in place.

Local Windows: 62/63 Python and 4/4 Node regression suites pass; the remaining
Python suite is the existing Keychain-retirement Git Bash mkdir permission issue.
Four native fragment generators and exact cache-reader/display-helper extraction
pass. Preservation checks confirm unchanged H6G protocol and all IdentifierManager
code outside the helper/WiFi fallback. Nine in-memory type/cache-only/observation
negative controls pass. Captured-command checks confirm four native configurations
for each fixture; those checks do not execute a compiler or Foundation binary.
Source-hardening, RootHide metadata/static and final targeted/diff checks pass.

Native Foundation, Logos/Theos, package and device execution remain unavailable
on Windows and require macOS CI. No H6H native pass, device coherence measurement,
performance gain or whole-manager thread-safety claim is made from these checks.
