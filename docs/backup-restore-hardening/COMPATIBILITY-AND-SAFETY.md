# Backup, Restore, and Clear Compatibility and Safety

Contract identifier: `PXBR-COMPATIBILITY-V1`

## 1. Authority and Scope

This document is the stable compatibility and safety contract for operators, support engineers, integrators, maintainers, and security reviewers working with Clear, Backup, and Restore.

Current production source is the behavioral authority. Build compatibility, format compatibility, source API compatibility, runtime ABI compatibility, safety semantics, test evidence, and target-device certification are separate claims. A source-level or CI result must not be presented as device certification.

The contract covers the canonical Clear, Backup, and Restore paths. It does not expand mutation authority, bypass validation, modify production behavior, certify a device, or turn an optional component into part of another transaction domain.

## 2. Quick Compatibility Matrix

<!-- PXBR-COMPAT-CONTRACT-BEGIN -->
| ID | Contract |
|---|---|
| C001 | The current build configuration declares iOS 12.0 as its deployment minimum; this is not certification of every iOS 12 or later device, jailbreak, bootstrap, or filesystem layout. |
| C002 | The current build architectures are arm64 and arm64e. |
| C003 | Typed destructive container resolution represents both rootful and rootless roots and requires exact resolved identity before mutation. |
| C004 | The implementation depends on privileged filesystem, helper, entitlement, and private-framework access and is not an App Store sandbox compatibility claim. |
| C005 | The canonical Backup and Restore entry points are createBackupForBundleID:appName:options:completion: and restoreBackupAtDirectory:bundleID:appName:completion:. |
| C006 | clearDataForBundleID:completion: is the canonical full five-scope Clear authority. |
| C007 | completeAppDataWipe: is a four-scope data-only compatibility authority and does not add Keychain execution. |
| C008 | The current AppDataCleaner source header exposes 24 instance methods; 18 destructive or quarantined declarations and 32 ambiguous aliases were removed from the public header while their runtime implementations were retained. |
| C009 | New Backup publication emits manifest version 4 with schema revision 2. |
| C010 | Restore execution and backup discovery support manifest versions 2, 3, and 4 only. |
| C011 | The UI scope-preview parser accepts integral versions 2 through 5, but version 5 is not supported by Restore execution or backup discovery. |
| C012 | Manifest version 4 uses schema identifier com.hydra.projectx.backup-manifest. |
| C013 | Manifest version 4 uses SHA-256 as its declared digest algorithm. |
| C014 | Manifest version 4 requires publication protocol atomic-directory-v1, content state complete, and backup mode strict. |
| C015 | The current manifest version 4 validator accepts schema revisions 1 and 2; revision 2 adds POSIX-mode and Data-Protection policy facts. |
| C016 | Restore requires the manifest bundle identifier to equal the exact requested bundle identifier. |
| C017 | Full Clear reports Application Data, Extension Data, App Groups, PluginKit Data, and Keychain as separate scopes. |
| C018 | Destructive Clear requires typed resolution, canonical path validation, retained identity, and postcondition evidence rather than path-prefix authority. |
| C019 | App Group mutation authority comes from exact signed application entitlements, not prefixes, company names, directory shape, or content heuristics. |
| C020 | Clear does not authorize writes into application bundle containers. |
| C021 | Ambiguous raw-path, raw-UUID, fuzzy, and structure-based legacy mutators are non-mutating compatibility shims. |
| C022 | The legacy BOOL and NSError Clear callback is derived from the final structured five-scope result. |
| C023 | A skipped Clear scope is not equivalent to a failed attempted scope. |
| C024 | Runtime selector retention for an old binary is not a declaration that the selector is public, canonical, or safe for new source. |
| C025 | Backup writes into a unique private partial workspace before publication. |
| C026 | Backup serialization uses one exclusive nonblocking flock for the exact canonical backup-root and bundle pair. |
| C027 | A manifest-authoritative artifact requires stable regular-file identity, exact size, streaming SHA-256, durability, and final namespace verification. |
| C028 | Required-artifact failure aborts Backup, while optional-artifact behavior follows its exact canonical failure disposition. |
| C029 | Published version 4 backup directories require mode 0700 and manifest or artifact regular files require mode 0600. |
| C030 | Final backup-directory publication is atomic and no-replace; an existing final name is never overwritten. |
| C031 | Current-operation cleanup is explicitly disarmed only after accepted publication and final identity validation. |
| C032 | Stale partial cleanup is descriptor-relative, bounded, fail-closed, and preserves ambiguous evidence instead of deleting an unproved namespace. |
| C033 | Restore constructs its immutable plan only from a validated manifest, verified artifacts, validated archives, and current exact destinations. |
| C034 | Main Application Data uses one transaction domain that either commits its accepted staged tree or attempts to restore its original tree. |
| C035 | App Group Restore treats all exact physical targets in one operation as a single leader-journaled batch. |
| C036 | Optional filesystem components use separate transaction domains, so a later domain failure does not globally undo an earlier durable domain commit. |
| C037 | Filesystem transactions use prepared, quarantined, installed, committed, rolling-back, and rolled-back journal phases. |
| C038 | Commit success requires a durable committed decision, and completed rollback requires a durable rolled-back decision. |
| C039 | Restore component status is one of Skipped, NotAttempted, Succeeded, or Failed. |
| C040 | Restore rollback status is one of NotPerformed, Completed, or Incomplete and is derived from retained transaction state rather than an error message. |
| C041 | Restore archive validation accepts exactly one gzip member and rejects unsupported compression, concatenated gzip members, and trailing compressed data. |
| C042 | Supported tar header families are legacy tar, POSIX ustar, and GNU tar. |
| C043 | Real archive members are limited to regular files and directories. |
| C044 | Symlinks, hard links, devices, FIFOs, sparse entries, unknown member types, and setid entries are rejected. |
| C045 | A normalized archive member path is limited to 4096 UTF-8 bytes and each component is limited to 255 UTF-8 bytes. |
| C046 | Archive validation limits references to 10000, physical headers to 400000, logical members per archive to 200000, and logical members per Restore to 500000. |
| C047 | Archive validation limits one metadata payload to 1 MiB, aggregate metadata to 16 MiB, one regular file to 64 GiB, inflated data per archive to 128 GiB, and inflated data per Restore to 256 GiB. |
| C048 | Archive validation does not extract the archive and binds validation to the verified compressed artifact size, digest, and stable filesystem identity. |
| C049 | The manager consumes only the structured Keychain helper V2 result protocol and has no V1 decode or downgrade path. |
| C050 | Keychain Restore performs no access-group-wide or class-wide pre-delete. |
| C051 | The overwrite request does not authorize broad deletion and does not guarantee replacement of every existing duplicate. |
| C052 | Keychain Restore uses add-first behavior, exact duplicate identity, and persistent-reference update for an accepted existing item. |
| C053 | A warning-only partial Keychain result may be reported as Succeeded with warnings, while substantive failed, skipped, or inconsistent item evidence is reported as Failed. |
| C054 | A Keychain execution failure may allow later Restore processing to continue, and Keychain reports rollback NotPerformed because it is outside the filesystem transaction domain. |
| C055 | The canonical Keychain backup artifact is optional, warns and continues on omission, rejects empty output, requires mode 0600, and requires Complete Data Protection. |
| C056 | Keychain result handling does not persist or expose raw stdout, stderr, commands, arguments, access-group values, item identities, or machine payloads. |
| C057 | Application Data is the mandatory base scope for Backup and Restore confirmation. |
| C058 | The seven advanced scopes are Profile App Data, Global Safari, App Groups, System Global, Shared System Databases, Global Preferences, and Keychain. |
| C059 | The direct Backup UI option switches select App Groups, Preferences, and Keychain; other advanced Restore scopes are derived from validated manifest facts. |
| C060 | Advanced-scope approval is explicit for the current operation and is not persisted as reusable consent. |
| C061 | Restore confirmation is bound to an immutable validated manifest snapshot and requires a second read with whole-manifest equality before execution. |
| C062 | A successful operation with warnings may indicate optional omission, bounded partial behavior, or cleanup residue and must not be interpreted as warning-free completeness. |
| C063 | Incomplete rollback means some data may remain changed or recovery evidence remains; operators must preserve evidence and must not blindly retry or manually delete transaction state. |
| C064 | Static checks, synthetic fault injection, and CI builds do not prove hardware power-loss behavior, every jailbreak layout, every device lock state, or every target-device runtime path. |
<!-- PXBR-COMPAT-CONTRACT-END -->

The audited table is the canonical compact contract. The sections below explain operational consequences without replacing the exact source-backed statements.

## 3. Platform and Deployment

| Property | Current build declaration | Interpretation |
|---|---|---|
| Theos target | `iphone:clang:16.5:12.0` | SDK and deployment settings for this build |
| Architectures | `arm64 arm64e` | Architectures emitted by the current configuration |
| Environment | Privileged jailbreak/tweak environment | Requires filesystem, helper, entitlement, and private-framework access |

The deployment target is not a tested-device matrix. The SDK version is not runtime certification. Successful private-framework compilation is not a promise of API stability. Rootful and rootless source paths are represented, but that does not certify every bootstrap or filesystem layout.

This project is not documented for a stock, non-jailbroken sandbox. Target-device support requires separate runtime evidence for the specific OS, device, jailbreak, bootstrap, entitlements, lock state, and storage layout.

## 4. Public API Compatibility

### Canonical Backup and Restore

Use `createBackupForBundleID:appName:options:completion:` for Backup and `restoreBackupAtDirectory:bundleID:appName:completion:` for Restore. These typed manager entry points remain the source API authorities.

### Clear source API and runtime ABI

| Property | Current state |
|---|---:|
| Public `AppDataCleaner` instance methods | 24 |
| Destructive or quarantined declarations removed by the first API-reduction step | 18 |
| Ambiguous alias declarations removed by the second API-reduction step | 32 |
| Runtime implementations retained | Yes |

Source compatibility changed intentionally: new code cannot compile against declarations that are no longer public. Runtime implementation retention is a static ABI-preservation measure, not a recommendation to call those selectors and not proof that every old binary works on a target device.

| Authority | Application Data | Extension Data | App Groups | PluginKit Data | Keychain |
|---|---|---|---|---|---|
| `clearDataForBundleID:completion:` | Yes | Yes | Yes | Yes | Yes |
| `completeAppDataWipe:` | Yes | Yes | Yes | Yes | No |

The data-only authority is not a synonym for full five-scope Clear.

## 5. Clear Safety Model

Clear plans and reports each scope independently. Application Data, Extension Data, App Groups, PluginKit Data, and Keychain retain distinct attempted, skipped, succeeded, and failed evidence.

Filesystem mutation requires a typed resolved container, exact identifier agreement, a canonical immediate-child path, retained filesystem identity, ownership and mode checks, and postcondition verification. A path prefix, raw UUID, fuzzy match, directory structure, or company-name resemblance is not mutation authority.

App Group authority comes from exact signed entitlements. Application bundle containers are not Clear destinations. Quarantined legacy methods retain runtime signatures but are non-mutating compatibility surfaces.

The legacy BOOL and NSError completion is computed only after the structured five-scope result is complete. A skipped scope records that no authorized attempt occurred; a failed scope records an attempted operation that did not satisfy its safety contract.

## 6. Backup Format Compatibility

| Use | v2 | v3 | v4 | v5 |
|---|---|---|---|---|
| Current Backup writer output | No | No | Yes | No |
| Restore execution | Yes | Yes | Yes | No |
| Backup discovery | Yes | Yes | Yes | No |
| UI scope-preview parsing | Yes | Yes | Yes | Yes |

Acceptance of version 2 or 3 still requires the complete current manifest validator, artifact verifier, archive validator, exact bundle identity checks, and immutable Restore planning. Historical version numbering alone does not make an arbitrary backup restorable.

Version 5 preview parsing is not version 5 Restore support. The UI can read scope facts for confirmation while execution and discovery continue to reject that version.

| Manifest version | Schema revision |
|---|---|
| Version 4 current writer | 2 |
| Version 4 validator compatibility | 1 and 2 |

Revision 1 omits the POSIX-mode and Data-Protection policy facts introduced by revision 2. Revision 2 requires those facts. Revision 1 is accepted compatibility input, not the current writer output.

Version 4 uses schema identifier `com.hydra.projectx.backup-manifest`, digest algorithm `sha256`, publication protocol `atomic-directory-v1`, content state `complete`, and backup mode `strict`.

## 7. Backup Publication and Discovery

Backup first creates a unique private partial workspace. A nonblocking exclusive lock serializes the exact canonical backup-root and bundle pair. Artifacts are written and verified before the final directory becomes discoverable.

An authoritative artifact must remain a stable regular file with the expected size and streaming digest, must be made durable, and must pass final namespace and identity verification. Required-artifact failure aborts the operation. Optional artifacts follow their declared failure disposition rather than an implicit global rule.

Published version 4 directories use mode `0700`; manifest and artifact regular files use mode `0600`. Final publication is atomic and no-replace. An existing final directory name is preserved rather than overwritten.

Current-operation cleanup is disarmed only after accepted publication and final identity validation. Stale partial cleanup is descriptor-relative, bounded, and fail-closed. Ambiguous or unproved namespaces are retained for diagnosis.

A partial workspace is not a published backup and is not valid Restore input.

## 8. Restore Validation and Planning

Restore execution accepts only versions 2, 3, and 4. It validates the full manifest, verifies the exact requested bundle identifier, verifies all selected artifacts, validates archives without extraction, resolves current exact destinations, and then constructs an immutable plan.

Scope-preview parsing is a UI confirmation aid. It is not an execution validator. Parse success alone does not authorize Restore.

Application Data is the mandatory base scope. Advanced scopes are represented only from selected Backup options or validated manifest facts, according to the operation. Restore confirmation stores an immutable manifest snapshot, re-reads the manifest before execution, and requires whole-manifest equality and equal derived scopes.

Unsupported manifest or archive input fails closed. Operators must not bypass identity, artifact, archive, or planning failures.

## 9. Transaction and Rollback Semantics

| Domain | Transaction boundary | Effect of a later unrelated-domain failure |
|---|---|---|
| Main Application Data | One main-data transaction | Main-domain rollback concerns only that domain |
| App Groups | One leader-journaled batch for all exact physical targets in the operation | Completed batch rollback restores earlier targets in that batch |
| Profile App Data | Separate optional transaction | Earlier durable domains are not globally undone |
| Global Safari | Separate optional transaction | Earlier durable domains are not globally undone |
| System Global | Separate optional transaction | Earlier durable domains are not globally undone |
| Shared System Databases | Separate optional transaction | Earlier durable domains are not globally undone |
| Preferences | Separate optional transaction | Earlier durable domains are not globally undone |
| Keychain | Outside filesystem transactions | Filesystem rollback does not apply |

Filesystem journals use `prepared`, `quarantined`, `installed`, `committed`, `rolling-back`, and `rolled-back`. Commit success requires a durable committed decision. A completed rollback requires the original state and a durable rolled-back decision.

| Rollback status | Meaning |
|---|---|
| `NotPerformed` | No filesystem rollback was reported for this component |
| `Completed` | The failed component reported its original state restored with a durable rolled-back decision |
| `Incomplete` | Rollback did not complete safely or recovery evidence remains |

Completed rollback is component- or domain-scoped. It does not undo an earlier committed domain. The optional filesystem domains are not one global transaction. A later failure can therefore leave an earlier domain committed.

One Restore operation's exact App Group physical targets form one batch. If a later target fails and rollback completes, earlier targets in that same batch are restored. This guarantee does not extend to unrelated optional domains or Keychain.

Keychain reports `NotPerformed` for rollback because it is outside the filesystem transaction domain.

## 10. Archive Compatibility and Limits

Archive validation accepts one gzip member containing a supported tar stream. Concatenated gzip members, trailing compressed data, unsupported compression, incomplete streams, and invalid streams are rejected.

Supported tar header families are legacy tar, POSIX ustar, and GNU tar. Real members are regular files or directories. Links, devices, FIFOs, sparse entries, unknown types, and setid entries are rejected. Validation inspects the archive; it does not extract it.

| Limit | Value |
|---|---:|
| References | 10,000 |
| Physical headers | 400,000 |
| Logical members per archive | 200,000 |
| Logical members per Restore | 500,000 |
| Normalized path bytes | 4,096 UTF-8 bytes |
| Component bytes | 255 UTF-8 bytes |
| One metadata payload | 1 MiB |
| Aggregate metadata | 16 MiB |
| One regular file | 64 GiB |
| Minimum inflated budget | 1 GiB |
| Inflation multiplier | 4,096 |
| Inflated bytes per archive | 128 GiB |
| Inflated bytes per Restore | 256 GiB |

Byte limits are byte limits, not character limits. Validation remains bound to the verified compressed artifact size, digest, and stable filesystem identity.

## 11. Keychain Compatibility and Safety

The manager accepts only the structured Keychain helper V2 machine result. There is no V1 decode or downgrade path. Raw helper output, command text, arguments, groups, item identities, and machine payloads are not result fields for operators.

Restore uses add-first behavior. On an exact duplicate and an accepted overwrite request, exact identity is resolved and an existing item may be updated by persistent reference. The overwrite flag is a replacement request, not broad deletion authority. Existing duplicates are not removed by access group or class, and replacement of every duplicate is not guaranteed.

Keychain Restore performs no access-group-wide or class-wide pre-delete. It is not a filesystem transaction and has no filesystem rollback. A substantive partial failure means some items may already have changed.

Warning-only partial evidence can produce a succeeded component with warnings when the structured counts are consistent. Failed, skipped, or inconsistent item evidence produces a failed component. A Keychain execution failure can be reported while later Restore processing continues.

The canonical Keychain backup artifact is optional, warns and continues when omitted, rejects empty output, requires mode `0600`, and requires Complete Data Protection. Mode alone is not proof of the required protection class; both mode and protection verification are required.

## 12. Advanced Scopes and Confirmation

Application Data is always the base scope for Backup and Restore confirmation. The seven advanced scopes are Profile App Data, Global Safari, App Groups, System Global, Shared System Databases, Global Preferences, and Keychain.

Direct Backup switches select App Groups, Preferences, and Keychain. Other advanced Restore scopes are derived from validated manifest facts. Approval applies only to the current operation and is not stored as reusable consent.

Restore confirmation is bound to an immutable validated manifest snapshot. Immediately before execution the manifest is read again, the whole manifest must equal the confirmed snapshot, and the derived scope set must remain equal.

## 13. Result and Warning Interpretation

A successful top-level operation can still contain warnings. Warnings must be interpreted according to the component and stage that produced them.

| Warning class | Operational interpretation |
|---|---|
| Optional artifact omitted | The optional component was not included; other accepted output may remain valid |
| Keychain helper partial result | Structured item evidence must determine whether the component succeeded with warnings or failed |
| Keychain protection failure and omission | The optional Keychain artifact is omitted rather than published without its policy |
| Post-commit cleanup residue | The durable committed data remains authoritative; diagnose retained cleanup evidence |
| Additional effective Keychain-group count | The signed helper had additional effective groups; no sensitive group value should be exposed |
| Diagnostic output truncation | Diagnostic completeness is reduced; raw output must not be promoted into the public result |

A warning must not expose sensitive group, path, item, command, argument, or machine-payload values. Warning-bearing success must not be interpreted as warning-free completeness.

Restore component status is `Skipped`, `NotAttempted`, `Succeeded`, or `Failed`. Rollback status is separate and must be interpreted from retained transaction state, not inferred from an error message.

## 14. Operator Recovery Guidance

Preserve the structured result and warning text. Preserve transaction, quarantine, and partial-workspace evidence after incomplete rollback. Do not remove reserved partial, quarantine, or transaction state before diagnosis, and do not blindly retry an incomplete rollback.

Distinguish earlier committed domains from the domain that failed. For a committed filesystem transaction with a cleanup warning, preserve installed data and diagnose only the retained cleanup evidence. For substantive partial Keychain failure, assume some items may have changed.

A later transaction construction can attempt production stale recovery. That behavior is not permission to discard evidence before diagnosis. Use the exact bundle identity for Restore and treat unsupported input as a fail-closed rejection.

Escalation evidence should include the structured operation result, component statuses, rollback statuses, warning text, manifest identity, and the presence of retained transaction evidence without copying sensitive payloads into support channels.

## 15. Unsupported Assumptions

Do not infer universal OS, device, jailbreak, bootstrap, entitlement, private-framework, or filesystem compatibility from the deployment target or architecture list.

Do not infer one operation-wide rollback across independent Restore domains. Do not infer Keychain transactionality or filesystem rollback. Do not infer execution support from UI preview parsing. Do not infer mutation authority from runtime selector presence, raw paths, UUIDs, prefixes, structure, or parse success.

Do not infer that archive validation extracts data, permits links or special files, or that a partial workspace is a published backup. Do not infer Complete Data Protection from mode `0600` without the protection-class check. Do not treat warnings as automatically harmless.

## 16. Evidence Status and Residual Limitations

| Evidence | Current meaning |
|---|---|
| Production source checks | Detect drift in the documented source contract |
| Compatibility document audit | Verifies exact contract text, structure, source proofs, and forbidden claims |
| Archive fixture tests | Exercise deterministic accepted and rejected archive cases |
| Transaction fault injection | Exercises synthetic POSIX faults, rollback paths, and fresh-process recovery on the CI host |
| Application build/package | Confirms the current source can be built in the configured CI environment when the workflow passes |
| Target-device certification | Requires separate evidence and is not supplied by the static document audit |

Static checks and synthetic tests do not reproduce hardware cache behavior, real power loss, every storage failure, every lock state, every private-framework variation, or every jailbreak layout. CI-host success remains distinct from device-runtime evidence.

Until remote evidence exists, archive Objective-C runtime, transaction Objective-C runtime, application build/package, and device behavior remain pending. This contract must be updated only when current production source and new evidence support the change.
