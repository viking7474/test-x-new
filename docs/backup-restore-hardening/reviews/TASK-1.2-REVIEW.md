# TASK-1.2 Coordinator Review

## Result

```text
Task: TASK-1.2 — Exact Application Data Container Resolver
Review status: ACCEPTED
Build gate: PASSED — reported by project owner
Reviewed implementation: uncommitted working-tree files
```

The agent report still records GitHub Actions as `PENDING`. The project owner's message that TASK-1.2 is complete is treated as the build-gate confirmation for workflow progression. No workflow URL or run ID was provided.

## Scope review

Task-owned production files are limited to:

```text
PXDataContainerResolver.h
PXDataContainerResolver.m
```

The required report exists at:

```text
docs/backup-restore-hardening/reports/TASK-1.2-REPORT.md
```

No existing production source imports or invokes `PXDataContainerResolver`.

At review time, TASK-1.1 and TASK-1.2 source artifacts are still untracked and are not isolated in dedicated commits. They should be committed before TASK-1.3 begins so the validator diff is independently reviewable.

## Accepted contract

The resolver:

- exposes one root-specific synchronous resolution method;
- uses fixed rootful and rootless application-data bases;
- does not accept a caller-controlled base path;
- enumerates immediate child names only;
- filters to UUID-named directory candidates;
- reads only `.com.apple.mobile_container_manager.metadata.plist`;
- reads only string `MCMMetadataIdentifier` values;
- uses exact case-sensitive `isEqualToString:` identity matching;
- returns no error for an absent base or zero exact matches;
- reports enumeration failures explicitly;
- reports multiple exact matches as ambiguity rather than choosing one;
- creates only `PXResolvedContainerKindApplicationData` candidates;
- reports an exact match that cannot construct the immutable model as `InvalidCandidate`.

## Root and identity review

Accepted fixed roots:

```text
PXResolvedContainerRootRootful
  /private/var/mobile/Containers/Data/Application

PXResolvedContainerRootRootless
  /containers/Data/Application
```

The rootful `/var/mobile/...` alias is not scanned as a second source. This prevents duplicate alias discovery from being interpreted as two distinct containers.

Requested and metadata identifiers are compared through one exact, case-sensitive equality check. No substring, prefix, suffix, lowercase, company-name, short-name, filename or content heuristic is present in the new resolver.

## Ambiguity and fail-closed behavior

Within one selected root:

```text
zero exact matches     -> nil, no error
one exact match        -> PXResolvedContainer
multiple exact matches -> nil, AmbiguousMatch
```

Sorting makes traversal deterministic but does not select a winner. A second valid exact candidate aborts resolution.

A matching metadata record that cannot produce `PXResolvedContainer` is not silently skipped. It returns `InvalidCandidate`.

## Filesystem boundary review

TASK-1.2 intentionally performs discovery only. It does not establish that the returned path is safe for deletion.

The resolver currently allows `fileExistsAtPath:isDirectory:` to follow a symlink to a directory. It does not use `lstat`, `realpath`, mount checks, ownership checks, mode checks or canonical allow-list enforcement. Those omissions are required by task scope and are the reason TASK-1.3 must precede caller migration.

## Static verification

Verified directly:

```text
PXDataContainerResolver interface: 1
PXDataContainerResolver implementation: 1
resolver declaration/implementation: 1 each
rootful fixed base: 1
rootless fixed base: 1
MCMMetadataIdentifier literal: 1
mobile-container-manager metadata filename: 1
containermanagerd fallback filename: 0
exact metadata equality: 1
containsString: 0
lowercaseString: 0
dispatch_apply: 0
CommandRunner: 0
NSTask: 0
posix_spawn: 0
deletion API: 0
canonicalization API: 0
existing production references: 0
```

Protected source diff is empty for `PXResolvedContainer`, `AppDataCleaner`, `AppGroupContainerResolver`, `AppDataBackupManager`, `CommandRunner` and `Makefile`.

`git diff --check` passes for tracked changes. TASK-1.2 source and report contain no trailing whitespace.

## Safety conclusion

TASK-1.2 is accepted as a standalone exact resolver contract. It improves identity discovery without changing current Clear, Backup, Restore, Keychain or UI behavior.

No destructive caller may consume its output until TASK-1.3 validates the candidate against a fixed kind/root base, canonical filesystem location, symlink and mount boundaries, ownership/mode policy and current metadata identity.

## Next authorized task

```text
TASK-1.3 — Canonical Destructive Path Validator
```

TASK-1.3 remains contract-only: it adds the safety boundary and returns a canonical path, but does not migrate `AppDataCleaner` or execute a destructive operation.
