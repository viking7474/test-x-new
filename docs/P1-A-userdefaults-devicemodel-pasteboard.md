# P1-A — UserDefaults / DeviceModel / Pasteboard hardening

Phase 1-A of `Newplan.md` §3. The Logos hooks were already implemented and
committed (in `90981a6` / `b7a7ae4`); this document records the acceptance rules
they satisfy and adds a host-runnable test over the pure decision logic so the
behaviour can be verified off-device and can never silently drift.

## Scope

| Hook file | Surface | Group / install |
| --- | --- | --- |
| `ProjectXTweak/UserDefaultsHooks.x` | `NSUserDefaults` getters | `%group UserDefaultsHooks` + `%init` after scope check |
| `ProjectXTweak/DeviceModelHooks.x` | `-[UIDevice model]` / `localizedModel` | `%group DeviceModelFoundation` + `%init` after scope/toggle/profile check |
| `ProjectXTweak/PasteboardHooks.x` | `UIPasteboard` | runtime installer (no blind `%init`) |

## Acceptance rules

### UserDefaults
- Only getters are hooked; setters live in a disabled `#if 0` block because Logos
  emits malformed C for the void setters in this pipeline.
- A `static __thread BOOL isInsideHook` recursion guard wraps every call into
  `getSpoofedUserDefaultsUUID`.
- `PXUserDefaultsIsUUIDKey` uses a strict allowlist; generic terms
  (token / tracking / device / identifier) are excluded.
- Values are rewritten only when the key is UUID-shaped **and** the value looks
  like a UUID (`PXUserDefaultsLooksLikeUUIDString`).
- `processDictionaryValues` preserves the immutable/mutable contract of the
  original collection.
- Spoofing is gated by scope + `isIdentifierEnabled:@"UserDefaultsUUID"`.

### DeviceModel
- `%group DeviceModelFoundation` hooks only `-[UIDevice model]` and
  `-localizedModel`; name / systemName / MGCopyAnswer / uname / sysctl / IOKit
  stay owned by Tweak.x and other modules.
- `PXDeviceModelUIDeviceFamily` maps a machine id to a generic Apple family
  (iPhone / iPad / iPod touch); unknown prefixes fall back to the original.
- `-model` never returns a machine identifier such as `iPhone15,3`.
- The constructor installs only after scope + `DeviceModel` toggle + a resolvable
  profile value.

### Pasteboard
- No file-level `%init`; a runtime installer checks the class, then each
  selector's existence and type encoding before hooking.
- Per-selector original IMP pointers (never a shared trampoline).
- Optional / private selectors (`uniquePasteboardUUID`,
  `pasteboardWithURL:create:`, `itemSetWithPreferredPasteboardTypes:`) are hooked
  only when they actually exist; a missing selector logs `unsupported-selector`
  **once** and continues.
- The general pasteboard name (`com.apple.UIKit.pboard.general`) is never renamed;
  only custom/unique pasteboards get a deterministic name derived from
  `PasteboardUUID` (`PXPasteboardDeterministicName`).
- No `NSNotificationCenter` hook is installed just for logging.

## Shared, testable helpers

`common/PXP1AFilters.{h,m}` holds the pure decision logic. The three hooks
delegate to it, and the host test links against the same file, so the shipping
behaviour and the test can never drift:

- `PXDeviceModelUIDeviceFamily`
- `PXUserDefaultsIsUUIDKey`
- `PXUserDefaultsLooksLikeUUIDString`
- `PXPasteboardDeterministicName`
- `PXPasteboardTypeEncodingCompatible`

## Build + run the host test

```sh
clang -fobjc-arc -framework Foundation \
  -Icommon \
  common/PXP1AFilters.m \
  tests/PXP1AFiltersTests.m \
  tests/PXP1AFiltersMain.m \
  -o /tmp/px_p1a_tests && /tmp/px_p1a_tests
```

Expected output ends with `ALL P1-A HELPER TESTS PASSED`.
`PXRunP1AFiltersTests()` returns the number of failed checks (0 on success).
