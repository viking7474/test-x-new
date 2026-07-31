# Phase 13 — Lockdown identity hook wiring

## Why this phase exists

Phases 4–7 and 12 delivered the Lockdown identity research stack:

- **Phase 4** — `PXLockdownResearchSafety` (policy, session runtime, safety decisions, redacted audit).
- **Phase 5** — `PXLockdownSoftwareModelProvider` (ProductVersion / BuildVersion / ProductType / DeviceName).
- **Phase 6** — `PXLockdownDeviceIdentityProvider` (UDID / SerialNumber / MLBSerialNumber).
- **Phase 7** — `PXLockdownSoCCellularProvider` (UniqueChipID / IMEI / IMEI2 / MEID / BasebandVersion).
- **Phase 12** — `PXLockdownObservability` (observe-only L0 inventory, forbidden-domain guard).

All of these were compiled, unit-tested, and build-gated — but **nothing was calling them at
runtime**. A repo-wide search confirmed there were zero references to any `PXLockdown*Resolve`
function inside `ProjectXTweak/`; the providers were reachable only from the static tests.

Phase 13 adds the missing glue: `ProjectXTweak/LockdownIdentityHooks.x`, which intercepts live
`liblockdown` value lookups and routes them through the safety-gated resolvers.

## What was added

| File | Purpose |
|---|---|
| `ProjectXTweak/LockdownIdentityHooks.x` | The runtime hook that wires `lockdown_copy_value` into the research resolvers. |
| `scripts/test_phase13_lockdown_hook_wiring_static.py` | Host-independent contract test pinning the safety invariants of the hook. |
| `scripts/release_hardening.py` | Registers the new static test in the release regression suite. |

No `Makefile` change is required: `ProjectXTweak_FILES` already globs `ProjectXTweak/*.x`, and the
entire hook body is behind `#if INTERNAL_SECURITY_RESEARCH`, so a release build compiles it to an
empty object and links no research symbols.

## How the hook works

1. **Build gate.** The whole translation unit is wrapped in `#if INTERNAL_SECURITY_RESEARCH`.
   `INTERNAL_SECURITY_RESEARCH` defaults to `0` and the `release-package` target forces
   `INTERNAL_SECURITY_RESEARCH=0`, so the hook is physically absent from shipping builds.

2. **Process gating (`%ctor`).** Mirrors `BootTimeHooks.x`:
   - skips processes with no bundle identifier and WebKit helper processes (`PXIsWebKitHelperProcess`);
   - builds a process-local `PXLockdownResearchRuntime` from the active profile settings and calls
     `activateAt:` (a persisted master switch never arms a session on its own — reboot fails closed);
   - **only installs the interception** when `policy.masterEnabled` is true **and** the current
     bundle id is in `policy.bundleAllowlist`. Every other process keeps zero Lockdown overhead.
   - registers Darwin observers (`com.hydra.projectx.settings.changed`, `…profileChanged`) to rebuild
     the runtime when the profile changes.

3. **Interception.** `lockdown_copy_value` is resolved dynamically
   (`dlopen("/usr/lib/liblockdown.dylib")` → `dlsym`, falling back to `RTLD_DEFAULT`) and hooked with
   `MSHookFunction`. If the symbol is unavailable the wiring is a safe no-op. The replacement only acts
   on the global (NULL/empty) domain, uses a `__thread` reentrancy guard, and honours copy (+1)
   ownership semantics (`CFBridgingRetain` on the replacement, `CFRelease` on the original).

4. **Key translation.** liblockdown is queried with bare runtime keys (`UniqueDeviceID`,
   `ProductType`, `InternationalMobileEquipmentIdentity`, …). The resolvers key off the documented
   firmware constant NAMES (`kLockdownUniqueDeviceIDKey`, …, plan §4.3). `PXLockdownConstNameForRuntimeKey`
   is the single translation table between the two namespaces.

5. **Dispatch.** For a mapped key the hook fetches the matching options via
   `PXLockdown*OptionsFromSettings(...)` and calls the matching `PXLockdown*Resolve(...)`
   (device-identity → software/model → SoC/cellular). Each resolver internally applies
   `PXLockdownOriginalOrReplacement`, so observe-only / denied / expired / type-mismatch /
   validation-failure all fall back to the original value.

6. **Audit.** Only redacted, value-free metadata is emitted via `PXLockdownRedactedAuditEvent`
   (logged once per key). Raw runtime values are never logged. Forbidden domains
   (pairing / certificate / private-key / escrow) are rejected up front via
   `PXLockdownObservationDomainIsForbidden`.

## Fail-closed summary

The hook returns the untouched original value on every one of: release build, non-allowlisted
process, master switch off, inactive/expired session, invalid snapshot, unmapped key, forbidden
domain, unavailable symbol, or any exception. A replacement is produced only when the safety runtime
explicitly authorises it and the resolver's validation passes.

## Verification

```
python3 scripts/test_phase13_lockdown_hook_wiring_static.py
python3 scripts/release_hardening.py regression
```
