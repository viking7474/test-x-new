# TASK-1.9 Review

## Verdict

```text
Task: TASK-1.9
Commit reviewed: 0bb2e354715e00f20c4df95719e900ae5e8e1673
Build gate: PASSED — reported by project owner
Production source review: ACCEPTED
Final status: COMPLETED
Next gate: TASK-1.10
```

TASK-1.9 is accepted. The migrated main Clear flow now represents App Groups as an exact typed component and no longer mutates App Group containers through legacy UUID reconstruction, fuzzy ownership rules or post-component bypasses.

## Scope reviewed

Production changes:

- `AppGroupContainerResolver.h`
- `AppGroupContainerResolver.m`
- `AppDataCleaner.m`

Task evidence:

- `docs/backup-restore-hardening/reports/TASK-1.9-REPORT.md`
- `docs/backup-restore-hardening/tasks/TASK-1.9-migrate-app-group-clear.md`

The commit changes only the three allowed production files plus the required report.

## Accepted implementation

### Typed App Group resolution

The new root-specific resolver:

- accepts only runtime string identifiers that are nonempty, non-whitespace-only and free of U+0000;
- maps rootful and rootless to fixed App Group bases;
- does not scan the `/var/mobile` rootful alias;
- enumerates deterministic immediate UUID children;
- rejects symlink candidate directories and metadata files;
- reads only `MCMMetadataIdentifier` from the fixed metadata plist;
- accepts one exact string or one exact array occurrence;
- rejects duplicate exact occurrences in one metadata array;
- fails closed on multiple physical exact matches;
- returns `PXResolvedContainerKindAppGroup`;
- contains no fuzzy authorization, shell execution or mutation.

The legacy `AppGroupContainerInfo` model and `resolveGroupContainersForGroupIDs:` selector remain source-compatible for current Backup/Restore callers.

### Signed entitlement identity

The migrated discovery path calls `fullEntitlementsForBundleID:error:` once per request and reads only:

```text
com.apple.security.application-groups
application-groups
```

It rejects malformed keys/elements, deduplicates exact identities and sorts deterministically. Legacy App Group metadata scans, bundle-prefix heuristics, company-name matching and container-content inspection do not authorize migrated mutation.

### Unique physical-container accounting

For each sorted identifier, rootful is processed before rootless. Resolver and validator errors are failed tuple units. Validated identities are grouped only after canonical validation by exact canonical path.

Multiple entitled identifiers mapping to one canonical physical container:

- produce one command;
- count as one physical attempted unit;
- retain every identity model;
- revalidate every model after the command.

This correctly handles App Group metadata arrays without duplicate destructive execution or distorted counts.

### Canonical mutation boundary

Each unique physical container uses:

```text
exact typed resolver
  -> canonical destructive validator
  -> one bounded result-returning strict wipe
  -> every alias identity revalidated
  -> strict postcondition
  -> final read-only postcondition
```

The migrated component contains no raw UUID reconstruction, raw `containerPath` reuse, batched group commands, void command wrappers, permission helpers or destructive final sweep.

### Four-scope aggregate

The data aggregate now contains exactly:

1. ApplicationData
2. ExtensionData
3. AppGroups
4. PluginKitData

ApplicationData no longer performs App Group discovery, mutation, cache writes or final sweeps. Callback precedence is deterministic:

```text
ApplicationData
ExtensionData
AppGroups
PluginKitData
Keychain
```

Keychain remains outside the typed aggregate until TASK-1.10.

### Cache and bypass removal

The old root-specific UUID caches were removed and replaced by:

```objc
NSArray<NSString *> *_wipeCacheAppGroupCanonicalPaths;
```

Cache-hit verification consumes validator-returned canonical paths directly. Cache-miss legacy inspection remains read-only.

The migrated main flow no longer performs App Group mutation through:

- deep encrypted-file scans;
- legacy App Group helper calls;
- App Group final sweeps;
- MobileSafari Shared/AppGroup substring scans;
- MobileSafari Shared/AppGroup structure scrubs.

MobileSafari global stores and SystemGroup behavior remain unchanged.

## Verification

The following gates passed:

```text
git show --check --oneline 0bb2e35
git diff 6f74381..0bb2e35 --check
protected production diff: clean
```

Static checks confirmed:

```text
typed resolver declaration/implementation: 1 / 1
legacy resolver declaration/implementation: 1 / 1
typed result kind: AppGroup
rootful /var/mobile alias in typed resolver: 0
typed resolver fuzzy tokens: 0
old group UUID caches: 0
canonical App Group cache: present
migrated App Group batch/raw-path/final-sweep tokens: 0
main-flow App Group encrypted scan: 0
MobileSafari Shared/AppGroup bypasses: 0
receipt tokens: 0
```

The report and new resolver files contain no trailing whitespace or NUL bytes. `AppDataCleaner.m` retains historical whitespace outside changed-line gates, while the committed diff passes `git show --check`.

## Remaining risks

- Runtime behavior still requires representative rootful/rootless device tests.
- Array-metadata alias collapse should be exercised on a real shared App Group container.
- Timeout, output truncation, identity replacement and final postcondition regression need injected/runtime coverage.
- Legacy App Group mutation APIs remain externally callable until the dedicated quarantine task.

These risks do not block TASK-1.9 acceptance because the required source boundary, accounting and compatibility contracts are implemented.
