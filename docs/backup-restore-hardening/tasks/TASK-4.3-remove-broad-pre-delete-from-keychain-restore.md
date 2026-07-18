# TASK-4.3 — Remove Broad Pre-Delete from Keychain Restore

- Status: READY
- Phase: 4 — Keychain Safety
- Baseline: `5c6e70ac4ecd815727c50216c80176d1cf9f80f2`
- Depends on: TASK-4.1 and TASK-4.2 accepted
- Next task: TASK-4.4 remains locked

## Objective

Remove the restore-time group/class-wide `SecItemDelete` operation that currently runs when `overwrite == YES`.

TASK-4.3 must make restore additive and non-destructive:

- existing Keychain entries are never deleted before item processing;
- only new items that `SecItemAdd` accepts are added;
- duplicate existing items remain unchanged;
- duplicate items are reported as per-item failures, producing a Partial structured result and exit `10` through the accepted TASK-4.1/TASK-4.2 layers;
- explicit wipe remains the only group/class-wide deletion API.

This task does not define exact per-class identity and does not implement update/upsert. Those remain exclusively owned by TASK-4.4 and TASK-4.5.

## Mandatory reading

Read before editing:

```text
docs/backup-restore-hardening/reviews/TASK-4.2-REVIEW.md
docs/backup-restore-hardening/reports/TASK-4.2-REPORT.md
KeychainHelper/KeychainBackupHelper.h
KeychainHelper/KeychainBackupHelper.m
KeychainHelper/PXKeychainHelperResult.h
KeychainHelper/PXKeychainHelperResult.m
KeychainHelper/PXKeychainHelperExitCode.h
KeychainHelper/backup_helper.m
scripts/keychain_backup.sh
AppDataBackupManager.m
AppDataCleaner.m
WeaponXKeychainBridge/Tweak.m
Makefile
```

## Authorized production scope

Only modify:

```text
M KeychainHelper/KeychainBackupHelper.h
M KeychainHelper/KeychainBackupHelper.m
M KeychainHelper/backup_helper.m
M scripts/keychain_backup.sh
```

Create the report:

```text
A docs/backup-restore-hardening/reports/TASK-4.3-REPORT.md
```

The implementation commit must contain exactly these five files.

## Protected files

Do not modify:

```text
KeychainHelper/PXKeychainHelperResult.h
KeychainHelper/PXKeychainHelperResult.m
KeychainHelper/PXKeychainHelperExitCode.h
Makefile
AppDataBackupManager.h
AppDataBackupManager.m
AppDataCleaner.h
AppDataCleaner.m
WeaponXKeychainBridge/Tweak.m
WeaponXKeychainBridge.plist
keychain_base_ent.plist
BackupKeychainGroupsViewController.h/.m
KeychainGroupsViewController.h/.m
ProjectXTweak/KeychainHooks.x
common/KeychainUUIDManager.h/.m
all Phase-1 through Phase-3 production source
all Restore plan/result/transaction/staging source
all UI/controller source outside the authorized helper help text
all coordinator documentation other than the required TASK-4.3 report
```

Do not stage, revert, delete, reformat or rewrite coordinator-owned modified/untracked documentation.

## Baseline evidence

Before editing, record:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -8 --oneline
git diff --check
```

Record SHA-256 and byte size before/after for every protected production file and all Phase-3 infrastructure.

# Part A — Eliminate restore-wide deletion

## Current unsafe behavior

The accepted baseline restore method performs this operation when `overwrite == YES`:

```text
read backup accessGroups
collect every _secClass from backup items
for each group x class:
    SecItemDelete(class + accessGroup + synchronizableAny)
then iterate backup items and call SecItemAdd
```

This can delete unrelated target items that share an access group and Security class but are absent from the backup.

TASK-4.3 must remove this authority completely.

## Exact restore mutation boundary

Inside:

```objc
+restoreKeychainFromFile:overwrite:error:
```

there must be:

```text
SecItemDelete calls: 0
SecItemUpdate calls: 0
SecItemAdd calls:    1 existing site
```

The method must not construct or execute any delete query.

Remove the complete pre-wipe block, including:

- the `if (overwrite)` group/class loop;
- reading `backup[@"accessGroups"]` for deletion;
- collecting a set of `_secClass` values for deletion;
- `kSecAttrSynchronizableAny` delete queries;
- `Pre-wipe failed` warning generation;
- comments claiming overwrite already performed a group-wide wipe.

No alternate broad delete may be added through:

```text
SecItemDelete
wipeKeychainForAccessGroups
performSelector
NSInvocation
function pointer
dlsym/private symbol
shell command
bridge call
notification
filesystem marker
```

## Repository-wide Security counts

After TASK-4.3:

```text
SecItemCopyMatching: unchanged at 5
SecItemAdd:          unchanged at 1
SecItemDelete:       exactly 1
SecItemUpdate:       0
```

The sole remaining `SecItemDelete` site must be inside the explicit wipe API:

```objc
+wipeKeychainForAccessGroups:itemClasses:error:
```

Do not alter that explicit wipe operation in this task.

# Part B — Transitional overwrite compatibility

## Public selector freeze

Keep the exact selector:

```objc
+restoreKeychainFromFile:overwrite:error:
```

Do not remove, rename or reorder the `overwrite` parameter.

Existing callers and shell forwarding remain source-compatible.

## Meaning of overwrite in TASK-4.3

`overwrite == YES` is a compatibility request only. It does not authorize any deletion or replacement in this task.

Until TASK-4.4/TASK-4.5 define exact identity and safe upsert:

```text
new item:
    SecItemAdd may succeed

existing duplicate item:
    preserve existing target item
    do not delete it
    do not update it
    report one failed item and one warning
```

Do not add a blanket warning merely because `overwrite == YES`.

A restore with `overwrite == YES` and only new items may still complete successfully.

The `overwrite` flag may only affect the human duplicate warning text defined below.

## Header documentation

Update only the restore selector documentation in `KeychainBackupHelper.h` so it no longer claims that overwrite deletes existing items.

The `overwrite` parameter documentation must state these facts:

- it is retained for compatibility;
- restore never deletes access-group/class contents up front;
- duplicate existing items are preserved and reported as item failures;
- safe replacement awaits per-item identity/upsert.

Do not change the selector, nullability, error enum, result class or any other public declaration.

# Part C — Duplicate handling

## One add attempt per valid item

Retain the existing add-query construction and exact one `SecItemAdd` call per valid dictionary item.

Do not add a preflight `SecItemCopyMatching` query for identity or existence. TASK-4.4 owns identity.

Do not add `SecItemUpdate`. TASK-4.5 owns upsert.

## Duplicate branch

Change duplicate handling so `errSecDuplicateItem` is handled identically with respect to counters for both overwrite values:

```text
itemsProcessed: already incremented once
itemsSucceeded: unchanged
itemsFailed:    increment once
warnings:       append exactly one duplicate warning
errors:         unchanged for the duplicate
existing item:  unchanged
```

The duplicate branch must not be conditioned on `!overwrite`.

Use exact warning formats:

When `overwrite == NO`:

```text
Item already exists; existing item was preserved: %@
```

When `overwrite == YES`:

```text
Overwrite requested but existing item was preserved pending safe per-item replacement: %@
```

The substitution remains:

```objc
addQuery[kSecAttrAccount] ?: @"unknown"
```

Do not add service, group, class, secret data or paths to these warning strings.

## Other add failures

Keep the existing generic non-duplicate `SecItemAdd` error path unchanged in behavior:

- append one human error;
- increment `itemsFailed` once;
- do not delete or update any existing item;
- continue processing later items.

Do not reclassify arbitrary Security failures as duplicates.

## Invalid backup items

Preserve existing behavior for:

- non-dictionary entries;
- missing `_secClass`;
- excluded restore attributes;
- wrapped data/date decoding;
- nil decoded values;
- synchronizable attributes;
- malformed item values currently accepted/skipped by the baseline implementation.

TASK-4.3 is not a backup-schema or strict-item-validation task.

# Part D — Structured result and exit behavior

Do not modify TASK-4.1 result construction or TASK-4.2 exit taxonomy.

The existing pipeline must naturally produce:

```text
all valid new items added:
    completion = completed
    exit = 0

one or more duplicates, with or without successful new items:
    completion = partial
    failedCount includes duplicates
    warningCount includes duplicate warnings
    exit = 10

non-duplicate per-item add failures:
    completion = partial
    exit = 10

critical restore input/parsing failure:
    existing Failed result and 20/21/30/40 mapping unchanged
```

Protocol failure precedence remains `50`.

Do not add an exit code, payload key or item-detail field.

Current manager/cleaner/bridge callers remain zero/nonzero consumers. Partial `10` continues to fail closed until TASK-4.8.

# Part E — CLI and wrapper truthfulness

## Direct helper help text

`KeychainHelper/backup_helper.m` may change only overwrite-related help/log wording outside the core call.

Replace the existing misleading help line with exact text:

```text
  --overwrite         For restore: request replacement; existing duplicates are preserved
```

Update the verbose restore start line from:

```text
Starting keychain restore (overwrite: %@)...
```

To exact:

```text
Starting keychain restore (overwrite requested: %@)...
```

Do not alter argument parsing, finalizer calls, exit classification, result creation or human warning/error loops.

## Shell wrapper help text

Replace the existing wrapper help line with exact text:

```text
  --overwrite   For restore: request replacement; existing duplicates are preserved
```

Do not alter:

- thirteen readonly exit constants;
- normalizer;
- wrapper setup mapping;
- helper status pass-through;
- helper argv;
- overwrite forwarding;
- `TEMP_DIR`;
- cleanup trap;
- entitlement extraction/generation/signing;
- target/group selection.

The wrapper must continue forwarding `--overwrite` unchanged when requested.

# Part F — Non-regression

## TASK-4.1 freeze

Keep byte-identical:

```text
KeychainHelper/PXKeychainHelperResult.h
KeychainHelper/PXKeychainHelperResult.m
```

Preserve:

```text
schemaVersion = 1
exact ten-key root
exact three-key fatalError
binary plist + base64
PXKEYCHAIN_HELPER_RESULT_V1=
fixed bounds
privacy exclusions
```

## TASK-4.2 freeze

Keep byte-identical:

```text
KeychainHelper/PXKeychainHelperExitCode.h
```

In `backup_helper.m`, preserve exact exit/finalizer structure:

```text
finalizer definitions:              1
non-help finalizer calls:          16
emitter definitions:                1
emitter calls outside definition:   1
raw direct return 1/2/3:        0/0/0
wrapper-only direct references:      0
```

In the shell wrapper, preserve:

```text
readonly exit constants: 13
normalizer definitions:    1
normalizer calls:          4
helper executions:         4
machine-result parsers:    0
result-prefix references:  0
```

## Backup behavior freeze

Do not change:

- backup file version/schema;
- backup item serialization;
- access-group enumeration;
- class selection;
- backup counts/warnings/errors;
- file writing behavior.

## Explicit wipe freeze

Do not change:

- wipe selector;
- group/class loops;
- count query;
- the sole remaining `SecItemDelete`;
- wipe warnings/counters.

## Restore input/parsing freeze

Do not change:

- path validation;
- file reading;
- plist parsing;
- top-level dictionary validation;
- `items` array validation;
- critical NSError domains/codes;
- excluded-attribute set;
- data/date decoding.

## Caller freeze

Keep byte-identical:

```text
AppDataBackupManager.h/.m
AppDataCleaner.h/.m
WeaponXKeychainBridge/Tweak.m
```

Do not add result parsing, exact-exit switches or new restore policy.

# Explicit task boundaries

Do not implement:

- TASK-4.4 exact identity for generic password, internet password, certificate, key or identity items;
- identity query builders;
- duplicate lookup;
- TASK-4.5 `SecItemUpdate` or per-item delete/add upsert;
- item rollback;
- backup schema migration;
- strict per-item backup validation;
- TASK-4.6 secure helper workspace/path validation;
- TASK-4.7 requested/effective group reporting;
- TASK-4.8 manager partial-result integration;
- TASK-4.9 backup-file protection;
- bridge protocol changes;
- UI changes;
- manifest changes;
- Phase 5 or Phase 6 work.

# Required static gates

Expected implementation scope:

```text
M KeychainHelper/KeychainBackupHelper.h
M KeychainHelper/KeychainBackupHelper.m
M KeychainHelper/backup_helper.m
M scripts/keychain_backup.sh
A docs/backup-restore-hardening/reports/TASK-4.3-REPORT.md
```

Required restore-core counts:

```text
restore method definitions:                    1
restore SecItemDelete sites:                   0
repository SecItemDelete sites:                1
repository SecItemUpdate sites:                0
repository SecItemAdd sites:                   1
restore backup accessGroups delete reads:      0
Pre-wipe failed literals:                      0
group-wide pre-wipe comments:                  0
duplicate status branches:                     1
duplicate branch conditioned on !overwrite:    0
overwrite duplicate warning variants:          2
```

Required TASK-4.1/TASK-4.2 counts remain unchanged as listed above.

Required protected diffs:

```text
PXKeychainHelperResult.h/.m: 0
PXKeychainHelperExitCode.h:  0
Makefile:                    0
manager:                     0
cleaner:                     0
bridge:                      0
Phase-3 production:          0
UI:                          0
```

# Validation matrix

The report must include explicit evidence for at least:

## Destructive-boundary cases

- overwrite false with empty target;
- overwrite true with empty target;
- unrelated item in same access group/class;
- unrelated synchronizable item;
- multiple backup classes;
- multiple backup access groups;
- accessGroups metadata containing a group with no backup item;
- backup item class absent from target;
- proof no delete occurs before first add;
- proof no delete occurs after add failure;
- proof explicit wipe still deletes.

## Duplicate cases

- duplicate generic-password item, overwrite false;
- duplicate generic-password item, overwrite true;
- duplicate internet-password item;
- duplicate certificate;
- duplicate key;
- duplicate identity;
- duplicate with account present;
- duplicate without account uses `unknown`;
- all items duplicate;
- one new plus one duplicate;
- duplicate followed by successful new item;
- successful new item followed by duplicate;
- multiple duplicates produce exact counts;
- duplicate does not append to errors;
- duplicate never calls delete/update;
- overwrite changes only duplicate warning text.

## Result/exit cases

- all new items -> Completed/0;
- all duplicates -> Partial/10;
- mixed success/duplicate -> Partial/10;
- generic add error -> Partial/10;
- critical file read failure -> existing InvalidInput exit;
- invalid plist -> existing InvalidInput exit;
- protocol construction failure -> 50;
- current manager treats 10 as nonzero;
- no machine schema change.

## Help/compatibility cases

- direct help no longer says delete existing items;
- shell help no longer says replace existing items unconditionally;
- direct `--overwrite` parsing remains;
- shell `--overwrite` forwarding remains;
- public selector unchanged;
- no blanket overwrite warning on all-new restore.

## Non-regression cases

- backup source hash behavior unchanged;
- explicit wipe behavior unchanged;
- TASK-4.1 files byte-identical;
- TASK-4.2 header byte-identical;
- finalizer/normalizer counts unchanged;
- manager/cleaner/bridge byte-identical;
- Makefile unchanged;
- Phase-3 source byte-identical.

# Required report

Create:

```text
docs/backup-restore-hardening/reports/TASK-4.3-REPORT.md
```

The report must include:

1. baseline and exact scope;
2. protected hashes and byte sizes;
3. baseline broad pre-delete inventory;
4. removed authority and Security-call counts;
5. overwrite compatibility semantics;
6. duplicate counter/warning behavior;
7. all-new restore behavior;
8. mixed restore behavior;
9. explicit wipe non-regression;
10. backup/input/parser non-regression;
11. TASK-4.1 structured-result behavior;
12. TASK-4.2 exit behavior;
13. direct and wrapper help updates;
14. zero identity/upsert proof;
15. zero manager/cleaner/bridge integration;
16. later-task boundary proof;
17. authorized full diff;
18. static-gate table;
19. at least 200 explicit numbered scenario rows;
20. shell syntax/static validation;
21. whitespace, CRLF, NUL and final-newline audit;
22. build/toolchain status and remaining device risks.

The report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

# Post-commit gates

Run and record:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff 5c6e70ac4ecd815727c50216c80176d1cf9f80f2..HEAD --check
git diff --name-status 5c6e70ac4ecd815727c50216c80176d1cf9f80f2..HEAD
git status --short --untracked-files=all
```

Expected commit manifest:

```text
M KeychainHelper/KeychainBackupHelper.h
M KeychainHelper/KeychainBackupHelper.m
M KeychainHelper/backup_helper.m
M scripts/keychain_backup.sh
A docs/backup-restore-hardening/reports/TASK-4.3-REPORT.md
```

Suggested commit:

```text
phase4(task-4.3): remove broad keychain restore pre-delete
```

Stop after TASK-4.3. Do not implement TASK-4.4 or any later task.
