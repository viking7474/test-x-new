# Phase 11 — P2 backlog cleanup

Phase 11 clears the remaining **P2** items from the Section 11 backlog in `new-plan.md`.
Every change is static-analysis verifiable via `scripts/test_phase11_p2_static.py`, which is
wired into `scripts/release_hardening.py` (`PHASE_TESTS`) and therefore runs in the regression
gate and CI.

## CLEAR-07 — remove process-wide `sync()`

The canonical mode-aware clear stopped calling `sync()` in Phase 8. The last remaining call sat
in the legacy Safari-specific cleanup helper in `AppDataCleaner.m`. A process-wide `sync()` forces
a global filesystem flush that blocks on unrelated I/O and provides no correctness benefit for a
targeted `rm -rf` sequence.

- **Change:** deleted the trailing `sync();` from the Safari cleanup helper and replaced it with a
  rationale comment.
- **Contract:** no standalone `sync();` remains anywhere in `AppDataCleaner.m`.

## CLEAR-09 — remove hard-coded competitor-brand SQL

`cleanDatabaseFile:bundleID:appName:companyName:` contained hard-coded `DELETE ... LIKE '%lyft%'`
style statements plus `com.lyft.ios` / `com.ubercab.UberClient` special cases. These embedded
third-party brand assumptions into a generic helper.

- **Change:** removed the brand-specific SQL block. Deletions are now driven only by the requested
  `bundleID` and its derived `appName` / `companyName`, which the helper already handled directly
  above and below the removed block.
- **Contract:** the method body between its signature and the `// Also try to delete data` comment
  contains no `%lyft%` / `%zimride%` / `%uber%` / `%helix%` SQL wildcards and no
  `com.lyft.ios` / `com.ubercab.UberClient` literals, while the generic bundle/app/company deletes
  remain.
- **Out of scope:** unrelated file-path handling elsewhere in the file (locationd / UI-State /
  Snapshot artifacts) is a separate concern and is intentionally not touched here.

## IOS-04 — `uname` ownership

The `uname` hook is installed exactly once, by the Tweak (`ProjectXTweak/Tweak.x`), via
`MSHookFunction`, guarded by `sPXUnameHookInstalled`. IOKit / sysctl /
`CFCopySystemVersionDictionary` are owned by `PXNativeHookCoordinator`; `uname` deliberately
remains a single Tweak-owned exclusive symbol rather than a multi-module hook.

- **Change:** added an explicit ownership marker comment documenting the canonical owner.
- **Contract:** the ownership marker is present, `uname` is hooked exactly once in the Tweak, the
  install guard exists, and no other hook module installs a `uname` hook.

## TIME-01 — opt-in device time offset

Added a new, self-contained module `common/PXTimeOffset.{h,m}` for an optional device time offset.
It mirrors the Phase 4 opt-in safety gating: **disabled by default**, gated by the
`com.weaponx.securitySettings` key `timeOffsetEnabled` (default `NO`).

- **Behavior:** when disabled (or when settings/values are missing or out of range) every accessor
  fails closed — a zero offset and an identity date passthrough. When explicitly enabled, the
  configured offset is clamped to +/- `PXTimeOffsetMaxAbsoluteSeconds` (24h).
- **Contract:** the public API is exported, the default-off / fail-closed / identity paths exist,
  and the bounded clamp is present.

## App-owned test mocks

`tests/phase11/mocks.json` holds app-owned, static-only fixtures for the Phase 11 contracts
(time-offset settings default OFF, a neutral fixture bundle for `cleanDatabaseFile`, and the
expected clamp). The static test asserts the mocks are app-owned, keep the time offset OFF, match
the module clamp, and never smuggle release-forbidden tokens.

## Verification

```
python scripts/test_phase11_p2_static.py
python scripts/release_hardening.py regression --iterations 2
python scripts/audit_backup_restore_hardening.py
```

> Note: Theos `.deb` builds and on-device / package-artifact checks are not run on the current
> Windows workstation; only the static Python contracts are executed here.
