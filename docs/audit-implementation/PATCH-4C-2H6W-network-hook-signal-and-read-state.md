# Patch 4C.2H6W — Network hook signal/radio state and defensive readers

Baseline: `20c5e2d`. The user reports the previous build passed. This batch
continues the NetworkConnectionTypeHooks follow-up from H6U, covering related
consumer state/read boundaries together. It does not complete Patch 4 or enroll
new source writers. The writer manifest remains H5S-partial.

## Findings and implementation

| Priority / severity | Evidence and location | Change / expected impact |
| --- | --- | --- |
| P1 / Medium logic defect | getWiFiSignalStrength and getCellularSignalBars shared lastSignalUpdateTime. Whichever helper refreshed first suppressed the other for 30 seconds. This is a source-level coupling defect; the current ctor does not install this file's legacy CNCopyCurrentNetworkInfo adapter, the only local WiFi-signal caller. No observed active WiFi/cellular interference is claimed. | Independent scalar value/time/validity/revision units. Each helper retains its own exclusive 30-second interval. |
| P1 / Medium potential | All three signal/radio helpers used wall-clock NSDate intervals. Moving wall time backwards could keep an old value fresh until the clock caught up. | CLOCK_MONOTONIC seconds with explicit nanosecond conversion, finite checks, zero-time validity and negative-age rejection. A failed clock cannot create a fresh interval; rollback establishes a new baseline. |
| P1 / Medium potential | Helper read/compute/write used separate critical sections. A Darwin notification or another reader could win between them, then an older computation could overwrite its state/timestamp. | Capture the unit revision before policy/RNG work; publish only if it still matches. Invalidation advances each revision. A losing operation returns the currently published value without retrying. Work and RNG stay outside the lock. |
| P2 / Low relative cost | Each signal read allocated an NSDate. Radio read copied/published an NSString and replaced an NSDate under the shared cache lock, even during the warm interval. | Signal/radio state is scalar-only; radio maps a captured enum to process-lifetime string literals after unlocking. Warm radio takes one critical section and no RNG. No Foundation call, allocation, copy or destructor occurs in these new signal/radio critical sections. Cost saving is low per call; aggregate impact depends on actual hook frequency and is not benchmarked. |
| P1 / Medium crash risk | Target-region/full-test toggle reads sent boolValue to arbitrary fields. Rootful carrier legacy fields could be numbers/arrays before length was sent. Valid property lists can contain these unexpected types. | Reuse PXRuntimeReadBool for toggles; share typed carrier source/field readers across package schemes. Keep nonempty whole-record precedence, legacy uppercase keys, defaults, branding fallback and empty-primary-string behavior. Dictionary root checks on IP/captured settings are defensive rather than proof Foundation's dictionary loader normally returns an array. |
| P1 / Medium potential | Rootful carrier reader resolved identity for two files, then called PXActiveProfileDeviceIDsPath again. A concurrent active-profile switch could select the third file from a different profile. | Read all three filenames beneath one captured identity directory. Named identity/path/partial dictionary roots have finally cleanup at the new helper/caller boundaries. No fallback to a newly active profile. This fixes path selection consistency, not concurrent mutation of file contents within that directory. |

## Preserved policies and scope

- WiFi starts at -65 dBm, retains the original target ranges, step limit of three
  plus jitter and clamp [-90, -40]. Cellular starts at four bars, retains target
  ranges, one-step progression and clamp [1, 5]. Invalidation keeps the numeric
  signal values as before, while revoking their intervals/candidates.
- Auto mode remains the existing process-stable random choice. Radio retains LTE
  as its invalidated baseline, 120-second minimum, 10% change-attempt probability,
  per-bar 5G probabilities and the NRNSA/NR split. A failed attempt after the
  interval still retries on the next call; it does not start a new 120-second
  throttle. A fresh interval still makes no random draws.
- RootHide retains captured-view carrier memoization and captured artifact/IP
  reads. No new profile/preference I/O is added to its reader branch. Signal/radio
  values remain process-local temporal simulation, not profile-tagged source
  authority. Both schemes use the same signal implementation.
- Hook methods, %orig, reachability/getifaddrs adapters, ctor/bootstrap/install
  admission, notifications and package/Makefile/dependencies are unchanged. The
  iOS 15.8.8/AIDA64 synchronous cold-bootstrap fix remains protected. Uninstalled
  legacy CF code is not installed or retired in this batch.

## Verification and limitations

New `scripts/test_network_hook_state.py` extracts exact production state, three
signal/radio functions, typed/IP helpers, carrier reader/force-toggle and the real
PXRuntimeReadBool implementation. `tests/PXNetworkHookStateTests.m` uses controlled
external clock/RNG/type/snapshot providers and real Foundation plist reads. It
covers real clock smoke, nanosecond units, finite/zero/rollback/failure cases,
29.999/exact30 and pre120/exact120 boundaries, both signal read orders, all modes
and progression bounds, probability thresholds, invalidation/reentrant winners,
throwing policy work, three real background/main publication interleavings,
typed/legacy/default/record precedence, RootHide view memo isolation, IP fallback
and rootful path-owner exceptional cleanup at each of the three read boundaries.

CI enrolls rootful and RootHide-defined builds in plain ARC and ARC exception
cleanup mode, all at -O0. These Foundation tests do not load Logos, private
CoreTelephony/UIKit classes, real captured runtime scope frames or Darwin
transport. They do not establish actual device selector ABI or signal-hook
reachability. CHECK macro arity, exact fragment generation and all four compile/
execution recipes are checked on Windows; recipe capture is not execution.

Windows regression: 63/64 Python suites and 4/4 Node suites. The established
Keychain retirement Git Bash mkdir /c/Users/ADMIN permission failure remains
(4 failures, 1 error, 1 skip). Source hardening, RootHide static/package checks,
exact hook/ctor-tail preservation, diff gates and 15 negative source controls pass.
Foundation/xcrun/Theos and device execution are unavailable on this host: the new
native matrix and packages still require macOS CI/device verification. No local
native/build/device pass or performance benchmark is claimed.

## Remaining work

ISO, pinned-region, connection-mode and carrier global caches still use their
existing NSDate/global-cache policies and have separate invalidation/publication
and object-release questions. This batch does not claim to fix them. Private
selector ABI/availability, legacy uninstalled CF ownership, hot-path logging and
within-profile multi-file snapshot consistency also remain separate. Full Patch
4 and later stages remain incomplete.
