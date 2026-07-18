# TASK-2.9 Review — Stage and Validate App Groups

Implementation commit reviewed: `48cb463b9f1bb6b1244237c227fa890f3020071d`

Production source review: **ACCEPTED**

Final status: **COMPLETED**

## Scope

The implementation commit contains exactly:

```text
M AppDataBackupManager.m
A PXAppGroupRestoreTargetPlan.h
A PXAppGroupRestoreTargetPlan.m
A docs/backup-restore-hardening/reports/TASK-2.9-REPORT.md
```

No protected production file changed. Coordinator-owned documentation remains outside the implementation commit.

## Commit gates

```text
git show --check: PASS
baseline-to-HEAD diff --check: PASS
implementation scope: PASS
uncommitted production diff: none
```

Baseline:

```text
9aaa575c7ce0e62aeb155c459879043e1ea5acfb
```

Reviewed HEAD:

```text
48cb463b9f1bb6b1244237c227fa890f3020071d
```

## Public target-plan contract

`PXAppGroupRestoreTargetPlan.h` exposes exactly:

- one error domain;
- one field-path key;
- nine public error codes;
- one immutable `PXAppGroupRestoreTarget` class;
- one immutable `PXAppGroupRestoreTargetPlan` class;
- one public factory;
- one exact group-ID lookup method.

Both public classes are subclassing-restricted, expose readonly properties, prohibit ordinary `init`/`new`, copy constructor inputs and return `self` from `copyWithZone:`.

Static counts:

```text
public error codes: 9
objc_subclassing_restricted: 2
public factories: 1
public lookup methods: 1
public readwrite properties: 0
copyWithZone implementations: 2
```

The public target objects contain only copied immutable identifiers, accepted resolved-container models, the validator-returned canonical path and immutable restore-plan items. They do not retain resolver, validator, staging workspace, descriptor, callback or command runner state.

## Exact signed-entitlement authorization

Restore reads signed App Group entitlements exactly once when the accepted plan contains included App Group items. Read failure or a non-array result is a hard generic target-plan-domain failure before main workspace creation, process termination or target mutation.

The target planner checks every entitlement element for:

- runtime `NSString` type;
- nonempty value;
- non-whitespace text;
- no NUL;
- no duplicate exact identifier.

Each planned group identifier must exact-match the entitlement set. There is no trimming, case folding, normalization, prefix, suffix or substring authorization. Extra entitled groups do not create work.

Manager static gates:

```text
applicationGroupsForBundleID: calls in Restore: 1
target-plan factory calls in Restore: 1
warning-only entitlement continuation: 0
```

## Typed rootful/rootless resolution

For every planned App Group identity, the target planner calls the accepted typed resolver in this exact order:

```text
rootful
rootless
```

Each root is queried once. Resolver errors fail the complete target plan. Nil with nil error remains an absent-root result.

Every non-nil model passes through `PXDestructivePathValidator`. Only the returned canonical path enters the target plan.

Outcomes are correct:

```text
both roots absent -> MissingTarget
one validated root -> accepted
same canonical path -> one physical target
separate canonical paths -> AmbiguousTarget
resolver error -> ResolverFailed
validator error/nil path -> ValidatorFailed
```

Legacy Restore authority is removed:

```text
resolveGroupContainersForGroupIDs: calls: 0
AppGroupContainerInfo variables: 0
legacy groupContainers array: 0
info.path authority: 0
info.uuid authority: 0
missing-manifest-mapping warning/skip: 0
```

The legacy resolver API and source remain unchanged for Backup or unrelated callers.

## Physical-target collapse

Logical group identities are grouped by exact validator-returned canonical path. The implementation preserves:

- first target occurrence order;
- group identifiers in restore-plan order;
- plan items in restore-plan order;
- each group's rootful/rootless model order.

Every associated group-ID lookup maps to the same immutable physical target. New physical targets are capped at 256; 256 is accepted and the 257th is rejected.

Fixed limits are present exactly once:

```text
planned items: 256
entitlement identifiers: 4096
physical targets: 256
```

## Per-target source staging

At the existing App Group component phase, Restore iterates `appGroupTargetPlan.targets`.

For every planned archive source it:

1. obtains archive identity and source path from the immutable restore-plan item;
2. obtains member-count and regular-file-byte summaries from `restorePlan.validatedArchives`;
3. validates summary values through the accepted exact unsigned-integral helper;
4. creates a private `PXMainDataStagingWorkspace`;
5. proves the workspace data directory empty;
6. extracts into `workspace.dataPath`;
7. requires zero extraction exit status;
8. validates the complete staged tree against the accepted archive summary;
9. retains only `PXValidatedMainDataStage.dataPath` as clone authority.

There is no direct backup-archive extraction into an App Group destination.

## Shared physical-target equivalence

When several planned group identities collapse onto one physical target, every archive is independently staged and validated before that target is wiped.

The first successful stage is retained. Every later stage must exact-match all of:

```text
treeSHA256
entryCount
regularFileCount
directoryCount
regularFileBytes
```

A mismatch cleans current and retained workspaces best effort and fails with a generic `InconsistentPlan` error before target mutation. The implementation does not select the first, last or newest conflicting archive and does not apply several archives sequentially to one target.

## Immediate destination revalidation

After all sources for one physical target have passed staging and equivalence, every retained `PXResolvedContainer` model is revalidated through `PXDestructivePathValidator`.

Each result must be nonempty and exact-equal the immutable target canonical path. The stored path is never replaced by a fresh output.

Failure cleans the retained stage and returns:

```text
domain: com.hydra.projectx.backup
code: 319
description: Exact App Group restore target could not be revalidated safely
```

The error does not expose group identifiers, paths, UUIDs, roots or nested validator errors.

## One wipe and validated clone

Each physical target is wiped once using `target.canonicalPath` only.

Clone source is `retainedGroupStage.dataPath` only. The implementation preserves the accepted tar-pipe xattr/ACL attempt, `/usr/bin/tar` and `/bin/tar` cp preference, and cp fallback after tar failure or unsupported xattrs.

Complete clone failure returns manager code 310 with the generic description:

```text
Failed to restore validated App Group stage
```

Successful clone is followed by existing ownership correction and workspace cleanup. Post-clone cleanup failure adds exactly:

```text
App Group staging cleanup failed
```

## Ordering

Relevant source ordering is:

```text
accepted PXRestorePlan
tar executable selected
signed entitlement read
target-plan construction
main staging workspace creation
first Restore process kill
...
App Group component phase
all source summaries collected for target
all archives staged and validated
source equivalence proven
all target models revalidated
one target wipe
clone from retained validated stage
chown
workspace cleanup
```

Target-plan failure therefore precedes main staging, process termination and all target mutation.

Per-target staging and revalidation precede that target's wipe.

## TASK-2.8 and prior-task non-regression

Protected diff is empty for:

```text
PXMainDataStaging.h/.m
PXRestorePlan.h/.m
PXBackupManifestValidator.h/.m
PXBackupArtifactVerifier.h/.m
PXBackupArchiveValidator.h/.m
PXResolvedContainer.h/.m
PXDataContainerResolver.h/.m
PXDestructivePathValidator.h/.m
AppEntitlementsReader.h/.m
AppGroupContainerResolver.h/.m
AppDataCleaner.h/.m
CommandRunner.h/.m
Makefile
UI/controller files
```

Main-data staging behavior, first-kill ordering, main target revalidation and manager codes 303/316/317 remain intact.

TASK-2.10 optional staging and TASK-2.12 App Group transaction/rollback behavior are not implemented.

## Independent static gates

```text
exact implementation scope: PASS
public error codes: 9
factory methods: 1
lookup methods: 1
signed entitlement reads in Restore: 1
target-plan factory calls: 1
rootful typed resolver call site: 1
rootless typed resolver call site: 1
canonical validator call sites in planner: 2
legacy aggregate resolver calls in Restore: 0
AppGroupContainerInfo in Restore: 0
physical-target iteration: present
workspace staging per source: present
empty validation per source: present
stage validation per source: present
shared-target equivalence: present
pre-wipe model revalidation: present
canonical target wipe call site: 1
direct archive extraction into group target: 0
validated-stage clone source: present
post-clone cleanup warning: 1
forbidden planner dependencies: 0
```

## Report quality

`TASK-2.9-REPORT.md` contains 180 explicit scenario rows, full scope/hash/static evidence, cleanup inventory, later-task boundaries and the required ending:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

New files contain no trailing whitespace or NUL bytes. `AppDataBackupManager.m` retains 17 preexisting trailing-whitespace lines; the implementation diff passes both commit and cumulative whitespace checks.

## Build gate

The report records no local Objective-C/Theos toolchain. The project owner continued to the next task, which is accepted as build confirmation under the established workflow. No GitHub Actions artifact or target-device runtime fixture is stored in this workspace for independent replay.

## Final decision

TASK-2.9 is accepted and completed.

TASK-2.10 may be opened. TASK-2.12 and later transaction work remain locked.
