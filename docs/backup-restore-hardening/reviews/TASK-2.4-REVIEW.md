# TASK-2.4 Review — Remove Recorded Restore Destination Fallbacks

Implementation commit reviewed: `c1d9067bab57085f71fb59443e81506c32237e3a`

Production source review: **ACCEPTED**

Final status: **COMPLETED**

## Scope

The implementation commit contains exactly:

```text
M AppDataBackupManager.m
A docs/backup-restore-hardening/reports/TASK-2.4-REPORT.md
```

All protected production files are unchanged. The coordinator working tree contains documentation-only artifacts and no uncommitted production diff.

## Accepted destination contract

Restore no longer selects its ApplicationData destination from:

- `manifest.data.containerPath`;
- `manifest.data.uuid`;
- `sourceDataContainerPath`;
- `sourceDataContainerUUID`;
- LaunchServices raw path output;
- legacy first-match metadata scans;
- caller-built base-plus-UUID paths.

`PXResolveExactRestoreApplicationDataTarget` is the only Restore destination-selection helper. It:

1. clears all outputs;
2. resolves rootful then rootless through `PXDataContainerResolver`;
3. fails on any resolver error;
4. validates every returned model with `PXDestructivePathValidator`;
5. retains only validator-returned canonical paths;
6. accepts zero paths only as failure;
7. accepts one unique canonical path;
8. collapses root aliases only when canonical paths are exactly equal;
9. fails when rootful and rootless produce distinct canonical paths;
10. returns generic manager code `303` without exposing nested resolver, validator, path, UUID or bundle data.

The retained `PXResolvedContainer` supplies `dataUUID`; the canonical validator output supplies `dataContainerPath`.

## Early preflight ordering

Independent source inspection confirmed this order:

```text
common manifest read
exact requested bundle comparison
exact destination helper
warnings / NSFileManager / CommandRunner setup
debug and tar discovery
process kill
artifact checks and staging
pre-mutation canonical revalidation
main ApplicationData wipe
```

Destination failure therefore occurs before Restore debug writes, tar lookup, process termination, artifact processing, extraction or target mutation.

## Pre-mutation revalidation

Immediately before `_wipeDirectoryContents:dataContainerPath`, Restore validates the retained model again and requires the returned canonical path to equal the preflight path exactly.

On revalidation failure it:

- removes staging best effort;
- returns manager code `303` on the main queue;
- does not wipe the target;
- does not run tar-pipe clone, cp fallback or target ownership correction.

## Static evidence

```text
PXDataContainerResolver import: 1
PXDestructivePathValidator import: 1
exact destination helper definition: 1
helper invocation in Restore: 1
rootful resolver calls: 1
rootless resolver calls: 1
helper validator calls: 2
Restore LaunchServices destination calls: 0
Restore legacy metadata destination calls: 0
Restore manifest containerPath reads: 0
Restore manifest UUID reads: 0
manifestDataUUID token: 0
recorded-path fallback warning: 0
recorded-UUID fallback warning: 0
pre-mutation validator calls: 1
pre-mutation canonical equality checks: 1
main target wipes: 1
```

Backup writer compatibility remains intact:

```text
data.uuid: retained
 data.containerPath: retained
sourceDataContainerUUID: retained
sourceDataContainerPath: retained
manifestVersion @3: retained
```

## Non-regression

Body hashes are unchanged for:

- `PXBackupManifestVersionIsSupported`;
- `readManifestAtBackupDirectory:error:`;
- `createBackupForBundleID:appName:options:completion:`.

TASK-2.1 schema validation, TASK-2.2 exact version set `{2,3}`, TASK-2.3 exact requested bundle comparison and code `304` remain intact.

Artifact verification, archive-entry inspection, immutable restore planning, component staging, transaction/rollback and structured Restore result behavior were not changed.

## Repository gates

```text
git show --check c1d9067: PASS
cumulative baseline-to-commit diff --check: PASS
protected production diff: PASS
implementation file scope: PASS
report scenarios: 85
report ending: correct
```

The report correctly states that no local Objective-C/Theos build was available. Build acceptance is recorded from project-owner continuation; no CI artifact is stored in this workspace.

## Remaining risk

Device validation is still required for rootful/rootless alias canonicalization, resolver ambiguity fixtures and concurrent filesystem identity changes. Artifact trust and archive contents remain intentionally untrusted until TASK-2.5 and TASK-2.6.
