# TASK-1.2 — Exact Application Data Container Resolver

## Metadata

- Phase: Phase 1 — Clear Data Safety Boundary
- Status: READY
- Dependency: TASK-1.1 accepted and project-owner build gate completed
- Required report: `docs/backup-restore-hardening/reports/TASK-1.2-REPORT.md`
- Allowed production files: create `PXDataContainerResolver.h` and `PXDataContainerResolver.m` only
- Suggested commit: `phase1(task-1.2): add exact application data resolver`

## Objective

Add a standalone resolver that locates an application data container by an exact `MCMMetadataIdentifier` match and returns the immutable `PXResolvedContainer` value introduced in TASK-1.1.

TASK-1.2 establishes exact resolution only. It must not:

- migrate `AppDataCleaner` or any existing caller;
- remove or rewrite legacy/fuzzy resolvers;
- authorize deletion;
- canonicalize paths or resolve symlinks;
- implement app-group, extension or PluginKit resolution;
- perform any Clear, Backup, Restore, Keychain or UI operation.

The result remains a candidate identity snapshot. TASK-1.3 must still validate the canonical destructive path before a future caller may delete anything.

## Required reading

Before editing, read:

1. `docs/backup-restore-hardening/README.md`
2. `docs/backup-restore-hardening/STATUS.md`
3. `docs/backup-restore-hardening/DECISIONS.md`
4. `docs/backup-restore-hardening/reviews/TASK-1.1-REVIEW.md`
5. `docs/backup-restore-hardening/reports/TASK-1.1-REPORT.md`
6. `docs/backup-restore-hardening/templates/AGENT_REPORT_TEMPLATE.md`
7. `PXResolvedContainer.h`
8. `PXResolvedContainer.m`
9. `Makefile`
10. `AppDataCleaner.h`
11. `AppDataCleaner.m`
12. `AppGroupContainerResolver.h`
13. `AppGroupContainerResolver.m`
14. `AppDataBackupManager.m` metadata verification helpers

Audit all existing application-data resolver families, including:

- `findDataContainerUUID:aggressive:`;
- `findDataContainerUUID:`;
- `findRootlessDataContainerUUID:aggressive:`;
- `findRootlessDataContainerUUID:`;
- `optimized_findDataContainerUUID:inDirectories:`;
- `optimized_findRootlessDataContainerUUID:inDirectories:`;
- `findDataContainerUUIDForBundleID:`.

This audit is informational only. None of those methods may change in TASK-1.2.

## Allowed changes

Create exactly:

- `PXDataContainerResolver.h`
- `PXDataContainerResolver.m`
- `docs/backup-restore-hardening/reports/TASK-1.2-REPORT.md`

Do not modify:

- `PXResolvedContainer.h`
- `PXResolvedContainer.m`
- `Makefile`
- `AppDataCleaner.h`
- `AppDataCleaner.m`
- `AppGroupContainerResolver.h/.m`
- `AppDataBackupManager.h/.m`
- `CommandRunner.h/.m`
- any UI, Clear, Backup, Restore or Keychain source.

The existing root `*.m` wildcard automatically includes `PXDataContainerResolver.m`; do not edit the Makefile.

## Public contract

### Error domain and codes

Declare in `PXDataContainerResolver.h`:

```objc
FOUNDATION_EXPORT NSString * const PXDataContainerResolverErrorDomain;

typedef NS_ENUM(NSInteger, PXDataContainerResolverErrorCode) {
    PXDataContainerResolverErrorInvalidInput = 1,
    PXDataContainerResolverErrorEnumerationFailed = 2,
    PXDataContainerResolverErrorAmbiguousMatch = 3,
    PXDataContainerResolverErrorInvalidCandidate = 4,
};
```

Do not add aliases or additional error codes in TASK-1.2.

### Resolver class

Declare:

```objc
__attribute__((objc_subclassing_restricted))
@interface PXDataContainerResolver : NSObject

- (nullable PXResolvedContainer *)resolveApplicationDataContainerForIdentifier:(NSString *)identifier
                                                                           root:(PXResolvedContainerRoot)root
                                                                          error:(NSError * _Nullable * _Nullable)error;

@end
```

The header must import `PXResolvedContainer.h`.

Do not add:

- singleton APIs;
- cache APIs;
- batch APIs;
- app-group/extension/PluginKit APIs;
- fuzzy/aggressive options;
- custom base-path input;
- custom `NSFileManager` input;
- asynchronous APIs;
- completion handlers.

## Error-pointer rules

At method entry:

```objc
if (error != NULL) {
    *error = nil;
}
```

The resolver returns:

| Outcome | Return | Error |
|---|---|---|
| invalid identifier/root | `nil` | `PXDataContainerResolverErrorInvalidInput` |
| selected base does not exist | `nil` | nil |
| selected base exists but is not a directory | `nil` | `PXDataContainerResolverErrorEnumerationFailed` |
| directory enumeration fails | `nil` | `PXDataContainerResolverErrorEnumerationFailed` |
| no exact metadata match | `nil` | nil |
| exactly one valid exact match | immutable object | nil |
| more than one valid exact match in the selected root | `nil` | `PXDataContainerResolverErrorAmbiguousMatch` |
| an exact metadata match cannot produce a valid `PXResolvedContainer` | `nil` | `PXDataContainerResolverErrorInvalidCandidate` |

Do not use exceptions for normal resolution outcomes.

Error descriptions must be concise and must not include container contents, file contents or command output. There is no command execution in this task.

## Input validation

The `identifier` input must:

- be an `NSString` at runtime;
- be nonempty;
- contain at least one non-whitespace/non-newline character;
- not contain Unicode U+0000.

Do not trim, lowercase, normalize or rewrite a valid identifier.

The `root` must be exactly one of:

- `PXResolvedContainerRootRootful`;
- `PXResolvedContainerRootRootless`.

Any other enum value is invalid input.

Do not impose bundle-ID syntax, prefix or component-count rules in TASK-1.2. Exact metadata equality is the identity rule.

## Fixed root mapping

Use exactly these resolver roots:

```objc
PXResolvedContainerRootRootful
    -> @"/private/var/mobile/Containers/Data/Application"

PXResolvedContainerRootRootless
    -> @"/containers/Data/Application"
```

Rules:

- scan only the selected root;
- do not scan both roots in one call;
- do not scan `/var/mobile/Containers/Data/Application` as a second rootful alias;
- do not scan bundle, app-group, PluginKit or SystemGroup bases;
- do not accept a caller-supplied base path;
- do not fall back to any other path.

The rootful path deliberately uses `/private/var/...` to avoid duplicate alias results. TASK-1.3 will own canonical path authorization.

## Filesystem and enumeration policy

Use `NSFileManager` synchronously and sequentially.

Required behavior:

1. Determine the fixed base from `root`.
2. Use `fileExistsAtPath:isDirectory:` on the base.
3. If the base is absent, return `nil` with no error.
4. If it exists but is not a directory, return `EnumerationFailed`.
5. Enumerate immediate children with `contentsOfDirectoryAtPath:error:`.
6. If enumeration fails, return `EnumerationFailed`.
7. Sort the returned child names with exact `compare:` before scanning, solely for deterministic behavior and reporting.
8. Do not recurse.
9. Do not use shell, `find`, `CommandRunner`, `NSTask`, `posix_spawn`, `system` or `popen`.
10. Do not use `dispatch_apply`, parallel queues or shared mutable result state.

### Directory-entry filtering

For each immediate child:

- require runtime `NSString`;
- require nonempty;
- skip names beginning with `.`;
- reject `.` and `..`;
- reject names containing `/` or U+0000;
- require `[[NSUUID alloc] initWithUUIDString:name]` to succeed;
- construct the candidate path with `stringByAppendingPathComponent:`;
- require the candidate to exist and be a directory before reading metadata.

Store the original directory-entry UUID string without reformatting it.

TASK-1.2 does not canonicalize the candidate and does not resolve symlinks. The future TASK-1.3 validator must reject unsafe canonical paths before deletion.

## Metadata policy

Read exactly one metadata filename:

```text
.com.apple.mobile_container_manager.metadata.plist
```

Do not read or fall back to:

```text
.com.apple.containermanagerd.metadata.plist
```

Do not search other files or inspect container contents.

For each candidate directory:

1. Build the metadata path by appending the exact filename.
2. Load it using `NSDictionary dictionaryWithContentsOfFile:`.
3. Skip the candidate unless the loaded object is an `NSDictionary`.
4. Read only the `MCMMetadataIdentifier` key.
5. Skip unless the value is an `NSString`.
6. Skip empty or whitespace-only metadata identifiers.
7. Skip metadata identifiers containing U+0000.
8. Match only with:

```objc
[metadataIdentifier isEqualToString:identifier]
```

Forbidden matching:

- `containsString:`;
- `hasPrefix:`;
- `hasSuffix:`;
- lowercase comparison;
- case-insensitive comparison;
- company/app-name heuristics;
- scanning filenames or directory contents;
- extension-prefix matching.

A malformed or unrelated container is skipped. It must not become a match and must not trigger destructive behavior.

## Candidate construction

For every exact metadata match, construct:

```objc
[[PXResolvedContainer alloc]
    initWithKind:PXResolvedContainerKindApplicationData
            root:root
 requestedIdentifier:identifier
  metadataIdentifier:metadataIdentifier
       containerUUID:uuid
       containerPath:candidatePath];
```

No other kind is permitted in TASK-1.2.

If this initializer returns `nil` for an exact metadata match, stop and return `PXDataContainerResolverErrorInvalidCandidate`. Do not silently ignore an exact match that violates the accepted value-object invariant.

## Ambiguity policy

Resolution is root-specific and must return at most one object.

- zero exact valid matches: `nil`, no error;
- one exact valid match: return it;
- two or more exact valid matches under the same selected root: return `nil` with `PXDataContainerResolverErrorAmbiguousMatch`.

Do not:

- select the first match;
- select the newest match;
- select by directory order;
- select by UUID sorting;
- merge results;
- return an arbitrary candidate.

The resolver may stop scanning once a second valid exact match is confirmed, provided it returns the ambiguity error and no candidate.

A rootful match and a rootless match are not ambiguous because they are resolved by separate calls with separate root values.

## No deletion authorization

A successful `PXResolvedContainer` from this resolver is still not sufficient for deletion.

TASK-1.2 must not add:

- `isSafeToDelete`;
- `canDelete`;
- an authorization flag;
- canonical-base validation;
- symlink validation;
- mount validation;
- owner/group/mode validation;
- destructive commands;
- file removal;
- permission changes.

Future callers must pass the candidate through TASK-1.3 before any destructive operation.

## No caller migration

No existing source may import or instantiate `PXDataContainerResolver` in TASK-1.2.

After this task, production references to the resolver class must exist only in:

- `PXDataContainerResolver.h`;
- `PXDataContainerResolver.m`.

`PXResolvedContainer` may be referenced by the new resolver, but no existing resolver or Clear caller may be changed.

Do not modify or deprecate legacy fuzzy methods yet.

## Baseline protection

Before editing, record `git status --short` and SHA-256 for:

- `PXResolvedContainer.h`
- `PXResolvedContainer.m`
- `Makefile`
- `AppDataCleaner.h`
- `AppDataCleaner.m`
- `AppGroupContainerResolver.h`
- `AppGroupContainerResolver.m`
- `AppDataBackupManager.h`
- `AppDataBackupManager.m`
- `CommandRunner.h`
- `CommandRunner.m`

After implementation, confirm all values are unchanged.

Do not stage, revert or format coordinator-owned documentation changes already present at baseline.

## Required report

Create:

```text
docs/backup-restore-hardening/reports/TASK-1.2-REPORT.md
```

The report must include:

1. task metadata and initial working-tree state;
2. exact files created;
3. public header contract;
4. error domain/code contract;
5. identifier/root validation;
6. fixed base mapping;
7. directory enumeration and filtering;
8. exact metadata filename/key policy;
9. exact equality proof;
10. candidate construction;
11. ambiguity policy;
12. no-match/error mapping;
13. proof no fuzzy resolver logic exists;
14. proof no command execution exists;
15. proof no existing caller changed;
16. resource ownership table;
17. protected-file checksums;
18. full diff and diff-stat review;
19. generated/binary audit;
20. static/runtime scenario matrix;
21. remaining risks;
22. GitHub Actions handoff.

## Required source gates

Run searches proving in the two new source files:

```text
PXDataContainerResolver interface: 1
PXDataContainerResolver implementation: 1
resolveApplicationDataContainerForIdentifier declaration: 1
resolveApplicationDataContainerForIdentifier implementation: 1
PXDataContainerResolverErrorDomain declaration: 1
PXDataContainerResolverErrorDomain definition: 1
PXResolvedContainerKindApplicationData construction: 1
rootful fixed base: 1
rootless fixed base: 1
MCMMetadataIdentifier: 1
mobile_container_manager metadata filename: 1
containermanagerd fallback filename: 0
containsString:: 0
identifier hasPrefix:/hasSuffix: matching: 0
case-insensitive matching: 0
CommandRunner: 0
NSTask: 0
posix_spawn: 0
system(: 0
popen(: 0
dispatch_apply: 0
file deletion APIs: 0
permission-changing APIs: 0
```

A `hasPrefix:@"."` check for hidden directory entries is allowed. No `hasPrefix:` may be used for identifier matching.

## Scenario matrix

At minimum review these scenarios:

| # | Scenario | Required outcome |
|---:|---|---|
| 1 | valid exact rootful match | rootful application-data object |
| 2 | valid exact rootless match | rootless application-data object |
| 3 | selected base absent | nil, no error |
| 4 | selected base exists but is file | enumeration error |
| 5 | enumeration fails | enumeration error |
| 6 | nil identifier | invalid-input error |
| 7 | dynamic non-string identifier | invalid-input error |
| 8 | empty identifier | invalid-input error |
| 9 | whitespace-only identifier | invalid-input error |
| 10 | identifier contains U+0000 | invalid-input error |
| 11 | invalid root enum | invalid-input error |
| 12 | no metadata file | candidate skipped |
| 13 | malformed metadata plist | candidate skipped |
| 14 | metadata key missing | candidate skipped |
| 15 | metadata identifier non-string | candidate skipped |
| 16 | metadata exact match | candidate considered |
| 17 | metadata differs by case | no match |
| 18 | metadata prefix-only match | no match |
| 19 | metadata substring match | no match |
| 20 | hidden directory entry | skipped |
| 21 | non-UUID directory entry | skipped |
| 22 | UUID entry is not directory | skipped |
| 23 | exact match produces invalid value object | invalid-candidate error |
| 24 | two exact matches in one root | ambiguous-match error, no object |
| 25 | one rootful and one rootless match via separate calls | each call can return its own object |
| 26 | metadata exists only under containermanagerd filename | no match in TASK-1.2 |
| 27 | candidate is symlink to directory | may resolve lexically; TASK-1.3 must decide safety |
| 28 | caller requests custom base | impossible; API has no such input |
| 29 | existing fuzzy resolver source | byte-for-byte unchanged |
| 30 | successful object used for deletion | impossible in TASK-1.2; no caller migration |

Every row must be marked `STATIC REVIEW` unless actually executed on a compiled target. Do not claim runtime PASS without evidence.

## Acceptance checklist

- [ ] Only two new production files and the required report are task-owned changes.
- [ ] Public resolver/error contract matches this specification.
- [ ] Resolver is root-specific.
- [ ] Fixed rootful/rootless bases are exact.
- [ ] Only immediate UUID-named directories are considered.
- [ ] Only the exact mobile-container-manager metadata filename is read.
- [ ] Only string `MCMMetadataIdentifier` is accepted.
- [ ] Matching is exact and case-sensitive.
- [ ] No fuzzy, prefix, substring or content heuristic exists.
- [ ] Successful result kind is always application data.
- [ ] Zero matches is not an error.
- [ ] Multiple exact matches fail closed as ambiguous.
- [ ] Invalid exact candidate fails closed.
- [ ] No shell, command runner or process API is used.
- [ ] No canonical/destructive path validator is implemented.
- [ ] No deletion or permission operation is implemented.
- [ ] No existing resolver or caller is changed.
- [ ] Protected files remain unchanged.
- [ ] Makefile remains unchanged.
- [ ] `git diff --check` and new-file whitespace checks pass.
- [ ] Full diff and generated/binary audit are complete.
- [ ] GitHub Actions is recorded as PENDING.
- [ ] Agent stops after TASK-1.2.

## Stop condition

After creating the resolver and report:

```text
Suggested status: READY_FOR_REVIEW
GitHub Actions: PENDING
```

Stop.

Do not:

- implement TASK-1.3;
- import the resolver into `AppDataCleaner`;
- change legacy fuzzy resolver behavior;
- perform destructive-path validation;
- migrate Clear Data;
- modify Backup, Restore, Keychain or UI behavior.

## Gate after TASK-1.2

1. Coordinator reviews the two new source files and report.
2. Project owner runs GitHub Actions.
3. TASK-1.2 becomes `COMPLETED` only after both pass.
4. TASK-1.3 may then be specified to add the canonical destructive-path validator.
5. Existing Clear callers remain locked until the resolver and validator contracts are both accepted.
