# Phase 8 — Clear Data Quick / Full / Deep

## Scope

Phase 8 keeps `clearDataForBundleID:completion:` as the canonical five-scope authority and `completeAppDataWipe:` as the data-only compatibility authority. It adds an explicit mode-aware overload without creating a parallel destructive path.

## Modes

| Mode | Application data | Extension / App Group / PluginKit | Keychain | Extra residual/system work | Verification |
|---|---:|---:|---:|---:|---|
| Quick | Yes | Explicitly skipped | One authorized pass when enabled | No | Exact component manifest |
| Full | Yes | Exact typed resolvers | One authorized pass when enabled | Bounded standard cleanup | Exact component manifest |
| Deep | Yes | Exact typed resolvers | One authorized pass when enabled | Bounded specialized cleanup | Manifest plus broad residual diagnostic scan |

The legacy request initializer maps `deepClean=NO` to Full and `deepClean=YES` to Deep. Existing UI behavior is preserved: the persisted `deepCleanEnabled` setting selects Full or Deep. New callers can request Quick explicitly.

## CLEAR-03 — validated container cache

`PXDataContainerResolver` now keeps a process-local cache keyed by identifier, kind and root. A hit is never trusted by age alone. Before reuse it rechecks:

- exact request/kind/root identity;
- UUID and expected canonical path shape;
- real, non-symlink container directory;
- real, non-symlink MCM metadata file;
- exact `MCMMetadataIdentifier` equality.

A failed hit is evicted. The canonical clear invalidates entries for the bundle at request completion, and public explicit invalidation APIs support install/uninstall/container-generation events.

## CLEAR-04 — one Keychain pass

Successful plans now contain exactly one pass. Authorization, selected-group, system-policy, disabled and no-selection semantics are unchanged. Result accounting fails closed unless both the plan and evidence contain exactly one pass.

## CLEAR-05/06/09 — mode boundaries and batching

Quick bypasses extension discovery, App Group discovery, PluginKit work, iCloud/residual scans, service refresh, app-specific system stores, Siri analytics and crash-log sweeps. It still uses the canonical application-data resolver/validator and the existing batched preferences/cookies command.

Full retains exact container coverage but does not invoke the legacy broad residual verifier or Deep-only specialized SQL paths. Deep is the only canonical mode that can invoke MobileMail/Safari specialized system cleanup, Siri analytics cleanup and crash-log sweeping. Legacy Uber/Lyft/Helix heuristic selectors remain outside the canonical mode-aware call graph.

The canonical path no longer deletes the cleaner process's global in-memory cookie jar.

## CLEAR-07/08 — sync and verification

The canonical clear no longer calls process-wide `sync()`. Quick and Full rely on the ordered `PXClearResult` component manifest plus the exact postconditions already applied to canonical paths. Deep additionally runs the existing broad residual scan as diagnostic evidence.

A legacy compatibility/special cleanup method still contains one isolated `sync()` and is not reachable from the canonical mode-aware entry point.

## CLEAR-10 — instrumentation

Structured log records include:

- mode and total duration;
- process-kill duration;
- Keychain duration and pass count;
- canonical data aggregate duration;
- verification duration, strategy and outcome;
- final success state.

No container paths or Keychain groups are emitted by these metric records.

## Validation

Run on any host with Python 3:

```sh
python scripts/test_phase8_clear_modes_static.py
```

The Objective-C policy harness is in `tests/PXClearModePolicyTests.m` and `tests/PXClearModePolicyMain.m`. Device/runtime behavior still requires the iOS/Foundation/Theos environment.
