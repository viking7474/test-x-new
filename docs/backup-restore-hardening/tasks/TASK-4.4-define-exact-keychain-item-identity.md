# TASK-4.4 - Define Exact Keychain Item Identity

- Status: READY
- Phase: 4 - Keychain Safety
- Baseline: `4c7000289186a4d7cb3772bc7c4b80b24ab4c3f1`
- Previous review: `docs/backup-restore-hardening/reviews/TASK-4.3-REVIEW.md`
- Expected report: `docs/backup-restore-hardening/reports/TASK-4.4-REPORT.md`
- Next task: TASK-4.5 remains LOCKED

## Goal

Create one immutable, class-specific Keychain identity authority that can derive an exact, bounded Security match-query snapshot from already-decoded item attributes.

TASK-4.4 is foundation-only.

It must not query, add, update or delete Keychain items and must not change current restore behavior. TASK-4.5 will consume this identity object for per-item upsert after TASK-4.4 is reviewed and accepted.

## Authorized implementation scope

```text
A KeychainHelper/PXKeychainItemIdentity.h
A KeychainHelper/PXKeychainItemIdentity.m
M Makefile
A docs/backup-restore-hardening/reports/TASK-4.4-REPORT.md
```

The implementation commit must contain exactly those four files.

## Protected files

Do not modify:

```text
KeychainHelper/KeychainBackupHelper.h
KeychainHelper/KeychainBackupHelper.m
KeychainHelper/PXKeychainHelperResult.h
KeychainHelper/PXKeychainHelperResult.m
KeychainHelper/PXKeychainHelperExitCode.h
KeychainHelper/backup_helper.m
scripts/keychain_backup.sh
AppDataBackupManager.h/.m
AppDataCleaner.h/.m
WeaponXKeychainBridge/Tweak.m
WeaponXKeychainBridge.plist
keychain_base_ent.plist
Keychain/UI source
Phase-1 through Phase-3 production source
Restore plan/result/transaction/staging source
coordinator task/review/status/roadmap/decision/README files
```

Do not stage, revert, delete, format or rewrite coordinator-owned modified/untracked documentation.

## Baseline evidence

Record before modification:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -8 --oneline
git diff --check
```

Record SHA-256 and byte size before and after for all protected production files.

# Public API

Create:

```text
KeychainHelper/PXKeychainItemIdentity.h
KeychainHelper/PXKeychainItemIdentity.m
```

## Public exports

Export exactly:

```objc
PXKeychainItemIdentitySchemaVersion
PXKeychainItemIdentityErrorDomain
PXKeychainItemIdentityErrorFieldPathKey
```

Exact values:

```text
schema version: 1
error domain:   com.hydra.projectx.keychain-item-identity
field-path key: fieldPath
```

## Identity-class enum

Define exactly:

```objc
typedef NS_ENUM(NSInteger, PXKeychainItemIdentityClass) {
    PXKeychainItemIdentityClassUnknown = 0,
    PXKeychainItemIdentityClassGenericPassword = 1,
    PXKeychainItemIdentityClassInternetPassword = 2,
    PXKeychainItemIdentityClassCertificate = 3,
    PXKeychainItemIdentityClassKey = 4,
    PXKeychainItemIdentityClassIdentity = 5,
};
```

Exact serialized/display class names retained by the object:

```text
unknown
generic-password
internet-password
certificate
key
identity
```

A successfully constructed object may never have class Unknown.

## Error codes

Define exactly twelve error codes:

```objc
PXKeychainItemIdentityErrorInvalidInput = 1,
PXKeychainItemIdentityErrorUnsupportedClass = 2,
PXKeychainItemIdentityErrorMissingAccessGroup = 3,
PXKeychainItemIdentityErrorInvalidAccessGroup = 4,
PXKeychainItemIdentityErrorMissingIdentityAttribute = 5,
PXKeychainItemIdentityErrorInvalidIdentityAttributeType = 6,
PXKeychainItemIdentityErrorInvalidIdentityAttributeValue = 7,
PXKeychainItemIdentityErrorInvalidSynchronizable = 8,
PXKeychainItemIdentityErrorAmbiguousIdentity = 9,
PXKeychainItemIdentityErrorLimitExceeded = 10,
PXKeychainItemIdentityErrorSnapshotFailed = 11,
PXKeychainItemIdentityErrorInternalInvariantFailed = 12,
```

## Immutable identity object

Create a subclassing-restricted:

```objc
PXKeychainItemIdentity : NSObject <NSCopying>
```

Readonly properties exactly:

```objc
@property (nonatomic, readonly) NSInteger schemaVersion;
@property (nonatomic, readonly) PXKeychainItemIdentityClass itemClass;
@property (nonatomic, copy, readonly) NSString *className;
@property (nonatomic, copy, readonly) NSString *accessGroup;
@property (nonatomic, readonly, getter=isSynchronizable) BOOL synchronizable;
@property (nonatomic, copy, readonly) NSArray<NSString *> *identityAttributeNames;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *identityAttributes;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *matchQuery;
```

Factory exactly:

```objc
+ (nullable instancetype)identityForSecurityItemAttributes:(NSDictionary<NSString *, id> *)attributes
                                                     error:(NSError **)error;
```

Unavailable:

```text
-init
+new
```

No public mutation, query-execution, update, delete, add, serialization, logging or secret-export API.

`copyWithZone:` returns `self`.

Equality and hash must use the complete retained identity state:

```text
schemaVersion
itemClass
accessGroup
synchronizable
identityAttributes
matchQuery
```

# Input boundary

The factory accepts an already-decoded Security item/add dictionary. It does not accept the raw wrapped backup-plist item format.

Require:

```text
input is NSDictionary
entry count <= 256
all identity keys are NSString Security constants
all required values pass exact runtime-type checks
```

The input may be mutable. The result must retain no caller-owned mutable object.

Clear `*error` on entry when an error pointer is provided.

Success:

```text
non-nil PXKeychainItemIdentity
error == nil
```

Failure:

```text
nil result
error != nil
no Objective-C exception escapes
```

Every reachable failure must set a specific error. Do not pre-populate a placeholder error.

Errors may contain only:

```text
NSLocalizedDescriptionKey with a bounded generic description
PXKeychainItemIdentityErrorFieldPathKey with a bounded field path
```

Do not include actual identity values, item dictionaries, access-group values, account/service/server strings, binary data, paths, secrets or underlying errors in userInfo.

# Fixed limits

```text
input dictionary entries:            256
access-group UTF-8 bytes:            1024
ordinary identity string UTF-8:      4096
constant-like string UTF-8:           255
issuer data bytes:                  65536
serial-number data bytes:            1024
application-label data bytes:        1024
identity attribute count:              10
match-query key count:                 10
aggregate retained identity bytes: 131072
field-path UTF-8 bytes:                255
```

All size arithmetic must be overflow-safe.

# Common identity attributes

Every supported class requires:

```text
kSecClass
kSecAttrAccessGroup
kSecAttrSynchronizable
```

## Security class

`kSecClass` must be exactly equal to one of:

```text
kSecClassGenericPassword
kSecClassInternetPassword
kSecClassCertificate
kSecClassKey
kSecClassIdentity
```

Do not infer class from `_class`, `_secClass`, labels, available attributes or data shape.

Do not accept a string that merely resembles a Security class constant.

## Access group

`kSecAttrAccessGroup` must be:

```text
NSString
nonempty
lossless UTF-8
<= 1024 UTF-8 bytes
no embedded NUL
no C0/C1 control characters
```

Do not trim, normalize, lowercase, wildcard-expand or substitute a missing access group.

## Synchronizable

If `kSecAttrSynchronizable` is absent, canonicalize it to exact false.

If present, require an exact CFBoolean object. Reject:

```text
integer NSNumber 0/1
floating NSNumber
NSString true/false
NSNull
NSArray
NSDictionary
NSData
NSDate
kSecAttrSynchronizableAny
```

Use exactly one file-local exact-CFBoolean extractor.

The retained query must always include an exact `@YES` or `@NO` synchronizable value. It must never contain `kSecAttrSynchronizableAny`.

# Exact class-specific identity tuples

No fallback tuple is allowed.

No identity may be constructed from label, description, comment, creation date, modification date, accessible class, access-control object, persistent reference, value data or secret data unless the attribute is explicitly listed below.

## Generic password

Exact tuple:

```text
kSecClassGenericPassword
kSecAttrAccessGroup
kSecAttrSynchronizable
kSecAttrAccount
kSecAttrService
```

`kSecAttrAccount` and `kSecAttrService` must each be exact NSString values.

They may be empty, but must be lossless UTF-8, control-free, NUL-free and at most 4096 bytes each.

Both keys must be present. Missing is not equivalent to empty.

Canonical identityAttributeNames order:

```text
kSecAttrAccessGroup
kSecAttrSynchronizable
kSecAttrAccount
kSecAttrService
```

Exact matchQuery key count: 5.

## Internet password

Exact tuple:

```text
kSecClassInternetPassword
kSecAttrAccessGroup
kSecAttrSynchronizable
kSecAttrAccount
kSecAttrServer
kSecAttrPort
kSecAttrProtocol
kSecAttrAuthenticationType
kSecAttrPath
kSecAttrSecurityDomain
```

String attributes:

```text
kSecAttrAccount
kSecAttrServer
kSecAttrPath
kSecAttrSecurityDomain
```

must be exact NSString values, present, lossless UTF-8, control-free, NUL-free and at most 4096 bytes.

`kSecAttrServer` must be nonempty. The other three may be empty.

Constant-like attributes:

```text
kSecAttrProtocol
kSecAttrAuthenticationType
```

must be exact nonempty NSString values, lossless UTF-8, control-free, NUL-free and at most 255 bytes.

Do not normalize or map protocol/authentication constants.

`kSecAttrPort` must be an exact non-Boolean NSNumber containing a finite integral value from 0 through 65535.

Reject fractional, NaN, infinite, negative, oversized, string and Boolean port values.

Canonical identityAttributeNames order:

```text
kSecAttrAccessGroup
kSecAttrSynchronizable
kSecAttrAccount
kSecAttrServer
kSecAttrPort
kSecAttrProtocol
kSecAttrAuthenticationType
kSecAttrPath
kSecAttrSecurityDomain
```

Exact matchQuery key count: 10.

## Certificate

Exact tuple:

```text
kSecClassCertificate
kSecAttrAccessGroup
kSecAttrSynchronizable
kSecAttrIssuer
kSecAttrSerialNumber
```

`kSecAttrIssuer` must be exact NSData, nonempty and at most 65536 bytes.

`kSecAttrSerialNumber` must be exact NSData, nonempty and at most 1024 bytes.

Do not fall back to:

```text
kSecAttrLabel
kSecAttrSubject
kSecAttrSubjectKeyID
kSecAttrPublicKeyHash
kSecValueData
certificate digest
```

Canonical identityAttributeNames order:

```text
kSecAttrAccessGroup
kSecAttrSynchronizable
kSecAttrIssuer
kSecAttrSerialNumber
```

Exact matchQuery key count: 5.

## Key

Exact tuple:

```text
kSecClassKey
kSecAttrAccessGroup
kSecAttrSynchronizable
kSecAttrApplicationLabel
kSecAttrKeyClass
kSecAttrKeyType
```

`kSecAttrApplicationLabel` must be exact NSData, nonempty and at most 1024 bytes.

`kSecAttrKeyClass` and `kSecAttrKeyType` must be exact nonempty NSString values, lossless UTF-8, control-free, NUL-free and at most 255 bytes.

Do not fall back to:

```text
kSecAttrApplicationTag
kSecAttrLabel
kSecAttrEffectiveKeySize
kSecAttrKeySizeInBits
kSecValueData
```

Canonical identityAttributeNames order:

```text
kSecAttrAccessGroup
kSecAttrSynchronizable
kSecAttrApplicationLabel
kSecAttrKeyClass
kSecAttrKeyType
```

Exact matchQuery key count: 6.

## Identity

Exact tuple:

```text
kSecClassIdentity
kSecAttrAccessGroup
kSecAttrSynchronizable
kSecAttrApplicationLabel
kSecAttrIssuer
kSecAttrSerialNumber
```

`kSecAttrApplicationLabel` must be exact NSData, nonempty and at most 1024 bytes.

`kSecAttrIssuer` must be exact NSData, nonempty and at most 65536 bytes.

`kSecAttrSerialNumber` must be exact NSData, nonempty and at most 1024 bytes.

Do not identify an identity from only certificate fields, only key fields, label, subject, persistent reference or value data.

Canonical identityAttributeNames order:

```text
kSecAttrAccessGroup
kSecAttrSynchronizable
kSecAttrApplicationLabel
kSecAttrIssuer
kSecAttrSerialNumber
```

Exact matchQuery key count: 6.

# Ambiguity rules

Return `PXKeychainItemIdentityErrorAmbiguousIdentity` when:

```text
class is supported but one of multiple possible identity schemes would be required
identity-only fallback fields are present but an exact required field is absent
certificate or identity issuer/serial pair is incomplete
key or identity application label is missing while alternate key metadata exists
internet-password primary tuple is incomplete while optional-looking fields exist
```

Do not choose a “best available” subset.

Missing a simple required attribute may use `MissingIdentityAttribute`; `AmbiguousIdentity` is for input that presents an apparent alternate identity path that the contract intentionally refuses.

# Exact immutable snapshots

`identityAttributes` must contain exactly the common and class-specific identity attributes, excluding `kSecClass`.

`matchQuery` must contain exactly:

```text
kSecClass
all identityAttributes entries
```

No matchQuery may contain:

```text
kSecMatchLimit
kSecReturnAttributes
kSecReturnData
kSecReturnRef
kSecReturnPersistentRef
kSecUseAuthenticationUI
kSecUseOperationPrompt
kSecValueData
kSecValueRef
kSecValuePersistentRef
kSecAttrSynchronizableAny
```

Use canonical insertion order internally even though NSDictionary equality is order-independent.

Deep-copy all NSString, NSData, NSNumber, NSArray and NSDictionary values retained by the object.

Only property-list-compatible immutable value types may appear in the two retained dictionaries.

No mutable collection or mutable data from the caller may remain reachable.

# Exception safety

Perform runtime-type proof before every type-specific selector such as:

```text
length
UTF8String
dataUsingEncoding:
boolValue
integerValue
longLongValue
doubleValue
isEqualToString:
```

The public factory must contain a final exception boundary that converts an unexpected Objective-C exception into `InternalInvariantFailed` without exposing exception text.

The exception boundary is defense-in-depth. It must not replace explicit type validation.

# Privacy and descriptions

Override `description` and `debugDescription` or otherwise prove they do not expose identity values.

A description may contain only:

```text
className
synchronizable true/false
identity attribute count
```

It must not contain:

```text
access-group value
account
service
server
path
security domain
issuer bytes
serial bytes
application label
protocol
authentication type
key type/class
```

Do not log input, errors, matchQuery or retained identity values.

# Pure foundation boundary

`PXKeychainItemIdentity.m` may import only:

```text
PXKeychainItemIdentity.h
Foundation
Security
CoreFoundation
bounded C headers required for arithmetic/type checks
```

It must not import:

```text
KeychainBackupHelper
backup_helper
AppDataBackupManager
AppDataCleaner
WeaponXKeychainBridge
CommandRunner
UIKit
```

The new module must contain zero calls to:

```text
SecItemCopyMatching
SecItemAdd
SecItemUpdate
SecItemDelete
SecItemImport
SecItemExport
```

It must contain no filesystem, process, shell, dispatch, network or logging operation.

# Makefile

Modify only the `backup_helper_FILES` assignment by adding exactly once:

```text
KeychainHelper/PXKeychainItemIdentity.m
```

Keep unchanged:

```text
backup_helper tool name
install path
frameworks
codesign flags
CFLAGS/LDFLAGS
script installation
bridge target
all other targets
```

# No integration in TASK-4.4

Keep byte-identical:

```text
KeychainHelper/KeychainBackupHelper.h
KeychainHelper/KeychainBackupHelper.m
KeychainHelper/backup_helper.m
scripts/keychain_backup.sh
```

TASK-4.4 must not:

```text
construct PXKeychainItemIdentity from current restore
reject or skip current restore items
query target Keychain
change duplicate handling
change overwrite behavior
change structured result
change exit code
change wrapper behavior
```

TASK-4.5 owns all consumption and mutation integration.

# Non-regression

Keep exact TASK-4.3 core Security counts:

```text
SecItemCopyMatching: 5
SecItemAdd:          1
SecItemDelete:       1
SecItemUpdate:       0
restore delete:      0
restore update:      0
```

Keep exact TASK-4.1/TASK-4.2 protocol and exit behavior:

```text
schemaVersion: 1
result root keys: 10
fatalError keys: 3
one result emitter
one finalizer
16 non-help finalizer calls
13 exit constants
one wrapper normalizer
four normalizer calls
```

Keep byte-identical:

```text
AppDataBackupManager.h/.m
AppDataCleaner.h/.m
WeaponXKeychainBridge/Tweak.m
Phase-1 through Phase-3 infrastructure
Restore infrastructure
UI/controllers
```

# Task boundaries

Do not implement:

```text
TASK-4.5 per-item upsert
SecItemCopyMatching identity lookup
SecItemUpdate
per-item SecItemDelete
add/delete rollback
backup schema migration
strict whole-item validation
secure temp workspace or path validation
requested/effective access-group reporting
manager/cleaner/bridge result parsing
backup-file protection
UI or later phases
```

# Required validation

Create deterministic unit/model coverage outside production source or in temporary harnesses without committing test artifacts unless already authorized.

Minimum matrix:

```text
all five valid classes
mutable-input deep-copy isolation
object equality/hash/copy
canonical match-query counts
missing common attributes
wrong common types
invalid access-group strings and limits
absent/valid/invalid synchronizable values
all class-specific missing attributes
all class-specific wrong types
empty and oversized data values
string UTF-8/control/NUL/limit cases
internet port integer boundaries and malformed numbers
ambiguous fallback attempts
extra nonidentity input attributes ignored
forbidden query-control/value keys absent
exception containment
privacy-safe description and NSError userInfo
```

At least 260 explicit numbered scenario rows are required in the report.

# Static gates

Expected:

```text
public exported constants:                    3
identity enum values:                         6
error codes:                                 12
readonly properties:                          8
public factories:                             1
public mutation methods:                      0
public Security-operation methods:            0
exact-CFBoolean helper definitions:           1
SecItemCopyMatching sites in new module:      0
SecItemAdd sites in new module:               0
SecItemUpdate sites in new module:            0
SecItemDelete sites in new module:            0
match-limit/return-control keys:               0
value-data/value-ref keys:                     0
logging sites:                                 0
filesystem/process/network sites:              0
Makefile identity source entries:              1
protected production diffs:                    0
```

Class query counts:

```text
generic-password matchQuery keys:  5
internet-password matchQuery keys: 10
certificate matchQuery keys:       5
key matchQuery keys:               6
identity matchQuery keys:          6
```

# Report

Create:

```text
docs/backup-restore-hardening/reports/TASK-4.4-REPORT.md
```

The report must include:

1. baseline and exact scope;
2. protected hashes and byte sizes;
3. current backup/add attribute inventory;
4. exact public API, enum and errors;
5. input/type/exception boundary;
6. common class/access-group/synchronizable rules;
7. generic-password tuple;
8. internet-password tuple;
9. certificate tuple;
10. key tuple;
11. identity tuple;
12. ambiguity and no-fallback proof;
13. immutable snapshot and deep-copy proof;
14. exact match-query key counts;
15. forbidden query/value controls;
16. privacy-safe error and description proof;
17. zero Security-operation proof;
18. Makefile exact diff;
19. TASK-4.1 through TASK-4.3 non-regression;
20. zero restore integration;
21. TASK-4.5 boundary;
22. full authorized diff;
23. static gate table;
24. at least 260 explicit numbered scenarios;
25. whitespace/CRLF/NUL/final-newline audit;
26. build/toolchain/device risks.

The report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

# Expected commit

```text
A KeychainHelper/PXKeychainItemIdentity.h
A KeychainHelper/PXKeychainItemIdentity.m
M Makefile
A docs/backup-restore-hardening/reports/TASK-4.4-REPORT.md
```

Suggested commit message:

```text
phase4(task-4.4): define exact keychain item identity
```

# Post-commit gates

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff 4c7000289186a4d7cb3772bc7c4b80b24ab4c3f1..HEAD --check
git diff --name-status 4c7000289186a4d7cb3772bc7c4b80b24ab4c3f1..HEAD
git status --short --untracked-files=all
```

Stop after TASK-4.4. Do not implement TASK-4.5 or any later task.
