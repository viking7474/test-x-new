# TASK-1.5 Report ? Typed Clear Request

## 1. Task metadata and scope

| Field | Value |
|---|---|
| Task | TASK-1.5 |
| Specification | `docs/backup-restore-hardening/tasks/TASK-1.5-typed-clear-request.md` |
| Baseline HEAD | `a2f5de8df684fe07f5adbf12c2513d6b223fd6d2` |
| Baseline subject | `a2f5de8 t?sk 1.2` |
| Production files created | `PXClearRequest.h`, `PXClearRequest.m` |
| Existing production files modified | None by TASK-1.5 |
| Report | `docs/backup-restore-hardening/reports/TASK-1.5-REPORT.md` |
| Runtime classification | STATIC REVIEW |
| Suggested state | READY_FOR_REVIEW |

This task creates an immutable request value object only. It does not execute Clear, modify the legacy Clear API, create a result model, integrate a caller, or begin TASK-1.6.

## 2. Required reading

The following files were read in full before source creation:

- `docs/backup-restore-hardening/tasks/TASK-1.5-typed-clear-request.md`
- `docs/backup-restore-hardening/README.md`
- `docs/backup-restore-hardening/STATUS.md`
- `docs/backup-restore-hardening/DECISIONS.md`
- `docs/backup-restore-hardening/reviews/TASK-1.4-REVIEW.md`
- `docs/backup-restore-hardening/reports/TASK-1.4-REPORT.md`
- `docs/backup-restore-hardening/templates/AGENT_REPORT_TEMPLATE.md`
- `PXResolvedContainer.h/.m`
- `PXDataContainerResolver.h/.m`
- `PXDestructivePathValidator.h/.m`
- `AppDataCleaner.h`
- `entire AppDataCleaner.m (6,388 lines / 328,347 bytes)`
- `Makefile`

Relevant accepted decisions: the request uses a closed five-bit scope set, application bundles/receipts are not representable, the default mask contains all five bits with deep clean disabled, validation is strict and non-normalizing, and caller integration remains locked for a later task.

## 3. Initial working tree and HEAD

Initial `git status --short --untracked-files=all`:

```text
 M AppDataCleaner.m
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? PXDestructivePathValidator.h
?? PXDestructivePathValidator.m
?? docs/backup-restore-hardening/reports/TASK-1.3-REPORT.md
?? docs/backup-restore-hardening/reports/TASK-1.4-REPORT.md
?? docs/backup-restore-hardening/reviews/TASK-1.3-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.4-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-1.4-remove-application-bundle-writes.md
?? docs/backup-restore-hardening/tasks/TASK-1.5-typed-clear-request.md
```

Initial repository identity:

```text
git rev-parse HEAD: a2f5de8df684fe07f5adbf12c2513d6b223fd6d2
git log -1 --oneline: a2f5de8 t?sk 1.2
```

`AppDataCleaner.m` was explicitly accepted as an uncommitted TASK-1.4 baseline. Its initial SHA-256 was `4642AE2482AF113E6C68FE89E2DC1FF2D04667E33BE2D2BD80E932F8D4BDC1D8`; TASK-1.5 did not edit, stage, revert, or format it.

## 4. File inventory

| File | Action | Purpose |
|---|---|---|
| `PXClearRequest.h` | Created | Closed scope contract and immutable public request API |
| `PXClearRequest.m` | Created | Validation, factory, copy, equality and hash implementation |
| `docs/backup-restore-hardening/reports/TASK-1.5-REPORT.md` | Created | Evidence and handoff |
| Existing production files | Not changed | No integration or behavior migration |

`Makefile` was not changed. Exact inclusion evidence:

```make
ProjectX_FILES = $(wildcard *.m) $(wildcard common/*.m)
```

Because `PXClearRequest.m` is a root-level `.m` file, the existing wildcard includes it automatically.

## 5. Exact public API

```objc
typedef NS_OPTIONS(NSUInteger, PXClearScope) {
    PXClearScopeApplicationData = 1UL << 0,
    PXClearScopeExtensionData   = 1UL << 1,
    PXClearScopeAppGroups       = 1UL << 2,
    PXClearScopePluginKitData   = 1UL << 3,
    PXClearScopeKeychain        = 1UL << 4,
};

FOUNDATION_EXPORT const PXClearScope PXClearScopeKnownMask;
FOUNDATION_EXPORT const PXClearScope PXClearScopeDefaultMask;

__attribute__((objc_subclassing_restricted))
@interface PXClearRequest : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSString *bundleIdentifier;
@property (nonatomic, assign, readonly) PXClearScope scopes;
@property (nonatomic, assign, readonly, getter=isDeepClean) BOOL deepClean;

- (nullable instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                                            scopes:(PXClearScope)scopes
                                         deepClean:(BOOL)deepClean
    NS_DESIGNATED_INITIALIZER;

+ (nullable instancetype)defaultRequestForBundleIdentifier:(NSString *)bundleIdentifier;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end
```

There are exactly three public properties and no additional initializer, builder, callback, path, UUID, timeout, serialization, mutation, resolver, validator, result, or behavior API.

## 6. Scope and mask contract

| Bit | Symbol | Numeric value |
|---:|---|---:|
| 0 | `PXClearScopeApplicationData` | 1 |
| 1 | `PXClearScopeExtensionData` | 2 |
| 2 | `PXClearScopeAppGroups` | 4 |
| 3 | `PXClearScopePluginKitData` | 8 |
| 4 | `PXClearScopeKeychain` | 16 |

Both exported constants are independently defined as the exact five-symbol union:

```objc
PXClearScopeApplicationData |
PXClearScopeExtensionData |
PXClearScopeAppGroups |
PXClearScopePluginKitData |
PXClearScopeKeychain
```

The numeric value of both `PXClearScopeKnownMask` and `PXClearScopeDefaultMask` is **31**. No application-bundle, receipt, system residual, arbitrary/custom, unknown, vendor, or `all` alias is declared.

## 7. Bundle identifier validation matrix

| Input/rule | Result | Source evidence |
|---|---|---|
| nil runtime value | Reject | Runtime `isKindOfClass:` check fails. |
| non-string runtime value such as NSNumber | Reject | Runtime `isKindOfClass:` check fails. |
| empty string | Reject | `identifier.length == 0`. |
| whitespace/newline only | Reject | No character outside `whitespaceAndNewlineCharacterSet`. |
| embedded U+0000 | Reject | Explicit NUL string search. |
| contains `/` | Reject | Explicit slash search. |
| contains `\` | Reject | Explicit backslash search. |
| contains `*` | Reject | Explicit wildcard search. |
| begins with `.` | Reject | First character check. |
| ends with `.` | Reject | Last character check. |
| contains `..` | Reject | Explicit repeated-dot search. |
| contains space | Reject | ASCII allowlist rejects it. |
| contains underscore | Reject | ASCII allowlist rejects it. |
| contains colon | Reject | ASCII allowlist rejects it. |
| contains non-ASCII character | Reject | UTF-16 code unit is outside the ASCII allowlist. |
| `COM.Example-App` | Accept unchanged | Uppercase ASCII, letters, hyphen and dots are allowed; no normalization. |
| `single` | Accept unchanged | A fixed dot-component count is not required. |
| `a-b.c9` | Accept unchanged | Every component is nonempty and all characters are allowed. |
| empty dot component | Reject | Component-length state rejects a dot when the current component is empty. |

Accepted input is stored through `_bundleIdentifier = [bundleIdentifier copy];`. There is no trim, lowercase, uppercase, Unicode normalization, separator rewrite, or prefix insertion call. Thus an accepted value such as `COM.Example-App` remains byte/character-for-character as supplied under NSString copy semantics.

## 8. Scope validation

The closed-mask predicate is:

```objc
return scopes != 0 &&
       (scopes & ~PXClearScopeKnownMask) == 0;
```

| Scope value | Result |
|---|---|
| 0 | Reject |
| 1 | Accept unchanged |
| 21 (`ApplicationData | AppGroups | Keychain`) | Accept unchanged |
| 31 (all known bits) | Accept unchanged |
| 32 (one unknown bit) | Reject |
| 63 (known plus unknown) | Reject |

The initializer does not strip unknown bits, add missing bits, replace zero, infer from the identifier, or merge global settings.

## 9. Deep-clean preservation

The designated initializer uses direct assignment:

```objc
_deepClean = deepClean;
```

No behavior is executed and no global setting is read. The field records exactly the boolean intent supplied by the caller.

## 10. Default factory behavior

```objc
return [[self alloc] initWithBundleIdentifier:bundleIdentifier
                                       scopes:PXClearScopeDefaultMask
                                    deepClean:NO];
```

The factory delegates to the designated initializer. Therefore invalid identifiers return nil through the same validation path; valid requests receive exact mask 31 and `deepClean == NO`.

## 11. Immutability and private ivars

- `_bundleIdentifier`, `_scopes`, and `_deepClean` are declared under `@private`.
- All three ivars are assigned directly in the designated initializer.
- The string is copied before storage.
- All public properties are readonly.
- There is no private readwrite redeclaration, class extension, setter, mutation method, mutable collection, singleton, or cache.
- The class does not conform to `NSMutableCopying`.
- `init` and `new` are unavailable.
- Subclassing is restricted.

## 12. Copy contract

`copyWithZone:` ignores the zone and returns `self`. This preserves identity because the request is immutable. No second mutable or partially copied representation is created.

## 13. Equality and hash contract

`isEqual:` first accepts pointer identity as a fast path, then requires exact class membership using `isMemberOfClass:`. Value equality compares:

1. exact `bundleIdentifier` string equality;
2. exact `scopes`;
3. exact `deepClean`.

`hash` starts from `bundleIdentifier.hash`, folds in `_scopes`, then folds in `_deepClean`. Equal values therefore use the same three state fields and produce equal hashes.

## 14. Forbidden-behavior proof

Only these imports exist:

```text
PXClearRequest.h: #import <Foundation/Foundation.h>
PXClearRequest.m: #import "PXClearRequest.h"
```

Forbidden-token counts across both new production files:

| Token/API | Count |
|---|---:|
| `AppDataCleaner` | 0 |
| `PXResolvedContainer` | 0 |
| `PXDataContainerResolver` | 0 |
| `PXDestructivePathValidator` | 0 |
| `NSFileManager` | 0 |
| `fileExistsAtPath` | 0 |
| `contentsOfDirectory` | 0 |
| `removeItemAtPath` | 0 |
| `createDirectoryAtPath` | 0 |
| `CommandRunner` | 0 |
| `NSTask` | 0 |
| `posix_spawn` | 0 |
| `system(` | 0 |
| `popen(` | 0 |
| `SecItem` | 0 |
| `UIKit` | 0 |
| `UIApplication` | 0 |
| `NSUserDefaults` | 0 |
| `dispatch_async` | 0 |
| `dispatch_sync` | 0 |
| `removeItem` | 0 |
| `createFile` | 0 |
| `writeToFile` | 0 |
| `moveItem` | 0 |
| `copyItemAtPath` | 0 |
| `chmod` | 0 |
| `chown` | 0 |
| `unlink(` | 0 |
| `rmdir(` | 0 |
| `truncate(` | 0 |
| `getenv(` | 0 |
| `NSProcessInfo` | 0 |
| `Bundle/Application` | 0 |
| `Containers/Data` | 0 |
| `metadata.plist` | 0 |
| `MCMMetadataIdentifier` | 0 |
| `PXClearResult` | 0 |

The required symbol `PXClearScopeKeychain` exists, but there is no Security import or Keychain API such as `SecItem`. The new files contain no filesystem path, bundle inspection, metadata, process, shell, deletion, creation, rename, permission, file-write, environment, user-defaults, UIKit, async-dispatch, Clear invocation, or result-model logic.

## 15. No-caller-integration proof

A search of 186 existing production source files (`.h`, `.m`, `.mm`, `.xm`, `.c`, `.cc`, `.cpp`), excluding the two new files, returned:

| Symbol | Existing production references |
|---|---:|
| `PXClearRequest` | 0 |
| `PXClearScope` | 0 |
| `PXClearScopeKnownMask` | 0 |
| `PXClearScopeDefaultMask` | 0 |
| `defaultRequestForBundleIdentifier:` | 0 |

No existing source imports, instantiates, accepts, returns, or invokes the request. The legacy Clear API and behavior remain unchanged.

## 16. Protected checksums

| Protected file | Initial SHA-256 | Final SHA-256 | Equal |
|---|---|---|---|
| `AppDataCleaner.h` | `B32A62280C2DF60A33658E7EC9193B76802D989C984C42193F045A94365C915E` | `B32A62280C2DF60A33658E7EC9193B76802D989C984C42193F045A94365C915E` | Yes |
| `AppDataCleaner.m` | `4642AE2482AF113E6C68FE89E2DC1FF2D04667E33BE2D2BD80E932F8D4BDC1D8` | `4642AE2482AF113E6C68FE89E2DC1FF2D04667E33BE2D2BD80E932F8D4BDC1D8` | Yes |
| `PXResolvedContainer.h` | `6BA935CB659EBDC5FDB8A96B13DD9F1450ACB2E284267AC82E8890287A686718` | `6BA935CB659EBDC5FDB8A96B13DD9F1450ACB2E284267AC82E8890287A686718` | Yes |
| `PXResolvedContainer.m` | `A782089C0605F8D7803FFB53F746A585AFB85F3FFBC9ED111F00575D77ADA8FB` | `A782089C0605F8D7803FFB53F746A585AFB85F3FFBC9ED111F00575D77ADA8FB` | Yes |
| `PXDataContainerResolver.h` | `D8A24BCCC9953FFF83CCF96F177BA33DAD1497EA62CEC7D17B78CFB8F2DED885` | `D8A24BCCC9953FFF83CCF96F177BA33DAD1497EA62CEC7D17B78CFB8F2DED885` | Yes |
| `PXDataContainerResolver.m` | `06B2DADA542DFB344DD36B1449A5B6B8FDD52874BA6AD8693CEDA2229EE39F30` | `06B2DADA542DFB344DD36B1449A5B6B8FDD52874BA6AD8693CEDA2229EE39F30` | Yes |
| `PXDestructivePathValidator.h` | `542E158A4F04BF50125E0064FBEBF02AC32F1DE07508C3F32058E770F75A3C0A` | `542E158A4F04BF50125E0064FBEBF02AC32F1DE07508C3F32058E770F75A3C0A` | Yes |
| `PXDestructivePathValidator.m` | `F275A60BE5CAB58E5D06DB3DD0987948F5EAB65DDD7E35E35E45927D238877CB` | `F275A60BE5CAB58E5D06DB3DD0987948F5EAB65DDD7E35E35E45927D238877CB` | Yes |
| `CommandRunner.h` | `63B88CF788FA8C981419F2C36F9375D1ED6E55190143C3C4E16B0972FE1D52BF` | `63B88CF788FA8C981419F2C36F9375D1ED6E55190143C3C4E16B0972FE1D52BF` | Yes |
| `CommandRunner.m` | `2D5D68CD307AB150D85A28DB69DD5A6169C40F78B3EB6FE49468BDAAE2475030` | `2D5D68CD307AB150D85A28DB69DD5A6169C40F78B3EB6FE49468BDAAE2475030` | Yes |
| `AppGroupContainerResolver.h` | `4F2A95CAE8F5C0DF5262F81B46061BFD45EAFBCDEADB0CA87C95F50BA3F32FCC` | `4F2A95CAE8F5C0DF5262F81B46061BFD45EAFBCDEADB0CA87C95F50BA3F32FCC` | Yes |
| `AppGroupContainerResolver.m` | `FACF3865907F031B0FFE870BFE5494AF418DB1EE0EDEC838F1AF5E50D579002A` | `FACF3865907F031B0FFE870BFE5494AF418DB1EE0EDEC838F1AF5E50D579002A` | Yes |
| `AppDataBackupManager.h` | `21B2A8DA95E155FF910CFEF0F489211C02A58E1A2B7486DA253871BEADC82D03` | `21B2A8DA95E155FF910CFEF0F489211C02A58E1A2B7486DA253871BEADC82D03` | Yes |
| `AppDataBackupManager.m` | `C40F4204D96D77211921320F8C43C889FE92D1714358BA37CA4713D2F43D6636` | `C40F4204D96D77211921320F8C43C889FE92D1714358BA37CA4713D2F43D6636` | Yes |
| `Makefile` | `22FB8F6E6095132F1AA6FACDB9C7A9995BF96DB47005DF31B82061C0A98C940F` | `22FB8F6E6095132F1AA6FACDB9C7A9995BF96DB47005DF31B82061C0A98C940F` | Yes |

Important baseline handling:

- `AppDataCleaner.m` remains exactly `4642AE2482AF113E6C68FE89E2DC1FF2D04667E33BE2D2BD80E932F8D4BDC1D8`.
- Its existing TASK-1.4 diff fingerprint remains `630CC99DD487C0B95BDC0E14AEC8549F5262BF8E61C64BF80C30FBC6004FB683` over 180 diff lines.
- `git diff --exit-code` for tracked protected files excluding this accepted pre-existing modified baseline returned 0 with empty output.
- A whole protected-set `git diff --exit-code` necessarily returns 1 because `AppDataCleaner.m` was already modified before TASK-1.5; start/final SHA-256 equality is the task-local proof that TASK-1.5 did not alter it.
- Untracked TASK-1.3 validator files also retain their start/final SHA-256 values.

## 17. Source-token gates

| Required gate | Result |
|---|---:|
| PXClearRequest interface | 1 |
| PXClearRequest implementation | 1 |
| public properties | 3 |
| designated initializer declaration | 1 |
| designated initializer implementation | 1 |
| default factory declaration | 1 |
| default factory implementation | 1 |
| scope enum single-bit entries | 5 |
| known-mask declaration/definition | 1 / 1 |
| default-mask declaration/definition | 1 / 1 |
| application-bundle scope | 0 |
| public setters | 0 |
| readwrite redeclarations | 0 |
| class extensions | 0 |
| NSMutableCopying | 0 |
| normalization method tokens | 0 |
| mutable collection tokens | 0 |
| filesystem/process/deletion/Security/UIKit/user-default/async APIs | 0 |
| existing production references outside new files | 0 for every required symbol |

Additional proof gates:

- zero scopes fail through `scopes != 0`;
- unknown bits fail through `(scopes & ~PXClearScopeKnownMask) == 0`;
- accepted identifier is copied without normalization;
- factory uses exact default mask and `NO`;
- equality and hash each include identifier, scopes, and deep-clean state.

## 18. Scenario matrix

| # | Scenario | Required/final result | Evidence | Classification |
|---:|---|---|---|---|
| 1 | valid identifier + default factory | Object uses exact default mask value 31 and `deepClean == NO`. | Factory directly delegates with `PXClearScopeDefaultMask` and `NO`. | STATIC REVIEW |
| 2 | valid identifier + one scope | Accepted. | Nonzero known bit passes the closed-mask check. | STATIC REVIEW |
| 3 | valid identifier + arbitrary known subset | Accepted unchanged. | Initializer assigns `_scopes = scopes` without repair. | STATIC REVIEW |
| 4 | all five known scopes | Accepted. | Known/default mask is exact union value 31. | STATIC REVIEW |
| 5 | `deepClean == YES` | Accepted and preserved. | Direct `_deepClean = deepClean` assignment. | STATIC REVIEW |
| 6 | nil/non-string identifier | Returns nil. | Runtime class validation precedes string operations. | STATIC REVIEW |
| 7 | empty identifier | Returns nil. | Explicit length check. | STATIC REVIEW |
| 8 | whitespace-only identifier | Returns nil. | Explicit non-whitespace check. | STATIC REVIEW |
| 9 | embedded U+0000 | Returns nil. | Explicit NUL check. | STATIC REVIEW |
| 10 | slash or backslash | Returns nil. | Both separators are explicitly rejected. | STATIC REVIEW |
| 11 | wildcard | Returns nil. | `*` explicitly rejected. | STATIC REVIEW |
| 12 | leading/trailing dot | Returns nil. | First and last character checks. | STATIC REVIEW |
| 13 | repeated dot | Returns nil. | `..` explicitly rejected and component state is nonempty. | STATIC REVIEW |
| 14 | space, underscore or colon | Returns nil. | ASCII allowlist rejects each. | STATIC REVIEW |
| 15 | uppercase valid ASCII identifier | Accepted and preserved. | Uppercase is allowed; no lower/upper/trim/normalization call exists. | STATIC REVIEW |
| 16 | zero scopes | Returns nil. | `scopes != 0` is required. | STATIC REVIEW |
| 17 | one unknown bit | Returns nil. | Unknown-mask expression fails. | STATIC REVIEW |
| 18 | known plus unknown bits | Returns nil. | Unknown bits are rejected, not stripped. | STATIC REVIEW |
| 19 | factory receives invalid identifier | Returns nil. | Factory delegates to designated initializer. | STATIC REVIEW |
| 20 | copy | Same object identity. | Immutable `copyWithZone:` returns `self`. | STATIC REVIEW |
| 21 | equal values in separate instances | `isEqual:` true and hashes equal. | Equality and hash include the same three fields. | STATIC REVIEW |
| 22 | different identifier | Not equal. | Exact identifier equality participates. | STATIC REVIEW |
| 23 | different scopes | Not equal. | Exact scopes value participates. | STATIC REVIEW |
| 24 | different deep-clean value | Not equal. | Exact deep-clean value participates. | STATIC REVIEW |
| 25 | application-bundle scope requested | Impossible. | No such enum bit or alias exists. | STATIC REVIEW |
| 26 | request executes Clear | Impossible. | No behavior API or existing caller integration exists. | STATIC REVIEW |

No row is labeled runtime PASS. Local Objective-C execution was unavailable because neither `clang` nor `make` is installed in this workspace.

## 19. Full diff and diff-stat review

Because the source files are new and untracked, file-specific no-index diffs were used:

| File | Insertions | Full no-index diff lines | Full diff SHA-256 | Review |
|---|---:|---:|---|---|
| `PXClearRequest.h` | 40 | 46 | `26BA7105FFEC3D164D8FF6069651BA696AB4F37CBD8222BD108A058E340E97D9` | Reviewed in full |
| `PXClearRequest.m` | 136 | 142 | `025B1B81E4691E79575ED5E83DEA0D328B2B5CE9DDB9FE291D4F83ECE0BBCF30` | Reviewed in full |
| Total | 176 | 188 | ? | Additions only |

The full diffs show only the exact closed option set, immutable request API, validation helpers, designated initializer, default factory, copy, equality and hash. No existing file hunk is part of TASK-1.5.

`git diff --check` does not inspect untracked files, so each new file was also checked with `git -c core.autocrlf=false diff --no-index --check -- NUL <file>`. Exit 1 means the file differs from empty; stdout and stderr were empty, proving no whitespace diagnostic.

## 20. Whitespace, NUL, generated and binary audit

| File | Bytes | Lines | SHA-256 | Trailing whitespace | NUL bytes | Text/binary |
|---|---:|---:|---|---:|---:|---|
| `PXClearRequest.h` | 1,288 | 40 | `D87402EE3720F1723977E4DEB3D78BC1DE87362948DFE585B5ED98F6447AE26B` | 0 | 0 | UTF-8 text |
| `PXClearRequest.m` | 4,389 | 136 | `AFC763AFC3306D422EF67EF3BD28A2A1A5741A64EA6078EE28F56F5D5901C790` | 0 | 0 | UTF-8 text |

- Both source files use LF line endings consistently.
- No generated build output, archive, object, image, database, cache or binary artifact was created.
- No source file was staged or committed.
- Report whitespace/NUL/text checks are performed after report creation and recorded in the final verification addendum below.

## 21. Remaining risks and handoff

1. Local compilation and runtime tests were not possible because `clang` and `make` are unavailable. GitHub Actions or the project owner build remains authoritative.
2. The model is intentionally unused. No Clear behavior is safer or more typed until a separately reviewed future integration task.
3. `deepClean` records intent only; TASK-1.5 deliberately defines no execution semantics.
4. Existing legacy Clear behavior, including the uncommitted accepted TASK-1.4 baseline, remains outside this task and unchanged.
5. TASK-1.6 remains locked; no `PXClearResult` was created.

## 22. Acceptance checklist

- [x] Only `PXClearRequest.h/.m` were created as production files.
- [x] Required report exists.
- [x] Public scope enum contains exactly five required single-bit entries.
- [x] Known and default masks are exact five-bit unions.
- [x] No application-bundle, receipt, arbitrary, unknown or all scope alias exists.
- [x] Public class has exactly three readonly properties and the required initializers/factory.
- [x] Bundle identifier validation implements every required rejection rule.
- [x] Accepted identifiers are copied without normalization.
- [x] Zero and unknown scopes are rejected without mask repair.
- [x] Valid known subsets and deep-clean values are preserved.
- [x] Default factory delegates with exact default mask and `NO`.
- [x] Private ivars and direct initializer assignments are used.
- [x] No setter, readwrite redeclaration, mutable collection or mutation API exists.
- [x] `copyWithZone:` returns self.
- [x] Equality and hash include all request state.
- [x] Forbidden-token audit is zero.
- [x] Existing production references outside new files are zero.
- [x] All protected checksums, including `AppDataCleaner.m`, are unchanged.
- [x] Makefile is unchanged and wildcard evidence is recorded.
- [x] Full no-index source diffs were reviewed.
- [x] Whitespace and NUL checks pass.
- [x] No generated or binary artifacts were created.
- [x] No `PXClearResult` or TASK-1.6 implementation exists.
- [x] Agent stops after TASK-1.5.
- [ ] GitHub Actions succeeds ? PENDING.
- [ ] Coordinator accepts TASK-1.5 ? PENDING.

## 23. Final verification addendum

Final repository identity remained stable:

```text
git rev-parse HEAD: a2f5de8df684fe07f5adbf12c2513d6b223fd6d2
git log -1 --oneline: a2f5de8 t?sk 1.2
```

Final `git status --short --untracked-files=all`:

```text
 M AppDataCleaner.m
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? PXClearRequest.h
?? PXClearRequest.m
?? PXDestructivePathValidator.h
?? PXDestructivePathValidator.m
?? docs/backup-restore-hardening/reports/TASK-1.3-REPORT.md
?? docs/backup-restore-hardening/reports/TASK-1.4-REPORT.md
?? docs/backup-restore-hardening/reports/TASK-1.5-REPORT.md
?? docs/backup-restore-hardening/reviews/TASK-1.3-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.4-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-1.4-remove-application-bundle-writes.md
?? docs/backup-restore-hardening/tasks/TASK-1.5-typed-clear-request.md
```

TASK-1.5-owned paths are only `PXClearRequest.h`, `PXClearRequest.m`, and `TASK-1.5-REPORT.md`. All other status entries are unchanged coordinator-owned baseline.

Final verification results:

```text
PXClearRequest interface/implementation: 1 / 1
public properties: 3
scope single-bit entries: 5
known-mask declaration/definition: 1 / 1
default-mask declaration/definition: 1 / 1
application-bundle scope: 0
readwrite/setter/NSMutableCopying: 0 / 0 / 0
forbidden API tokens: 0
existing production references outside new files: 0
PXClearResult source files: absent
TASK-1.6 report: absent
protected SHA-256 equality: true
tracked protected diff excluding accepted AppDataCleaner baseline: exit 0
git diff --check: exit 0
scenario rows: 26 STATIC REVIEW
validation rows: 19
source/report NUL bytes: 0
source/report trailing whitespace: 0
generated/binary artifacts: 0
```

`git diff --check` emitted only LF-to-CRLF warnings for pre-existing coordinator-owned documentation. File-specific no-index checks for the two new source files and this report returned the expected difference exit 1 with empty stdout/stderr, meaning no whitespace diagnostic.

Local Objective-C build and runtime tests were not run because `clang` and `make` are unavailable. No runtime PASS is claimed.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
