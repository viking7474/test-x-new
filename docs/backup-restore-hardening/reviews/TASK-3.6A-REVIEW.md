# TASK-3.6A Review

Implementation commit reviewed: `3a7d3f8fe8a98747fe6c823167250e43b8159e9f`

Production source review: **ACCEPTED**

Corrective status: **COMPLETED**

Parent TASK-3.6 final status: **COMPLETED**

TASK-3.7 may open: **YES**

## Scope

The implementation commit contains exactly:

```text
M PXBackupManifestV4.m
M PXBackupManifestValidator.m
A docs/backup-restore-hardening/reports/TASK-3.6A-REPORT.md
```

No public header, manager, artifact policy/writer, workspace/lock, Restore, UI, Makefile, CommandRunner or Keychain source changed.

## Corrective blocker closure

TASK-3.6 was blocked because malformed v4 dictionary values could receive type-specific Objective-C selectors before runtime type proof.

The corrective implementation now centralizes exact extraction:

```text
builder exact-Boolean helper definitions:   1
validator exact-Boolean helper definitions: 1
validator policy string-class gate:          1
```

Only the two centralized Boolean helpers call `boolValue`, and both first require:

```text
runtime NSNumber
exact CFBoolean type
```

Independent source scan:

```text
builder raw dictionary-subscript boolValue:       0
validator v4 raw dictionary-subscript boolValue:  0
builder raw dictionary-subscript isEqualToString: 0
validator v4 raw dictionary-subscript equality:   0
```

The one remaining raw dictionary equality pattern in the validator is in the byte-identical legacy v2/v3 path and is outside TASK-3.6A scope.

## Builder type safety

`PXBackupManifestV4.m` now performs typed extraction before comparison or Boolean use for:

- bundle ID and backup mode;
- Restore target bundle identity;
- Restore compatibility Booleans;
- all three requested options;
- Preferences inclusion and archive;
- Keychain inclusion, archive and method;
- profile AppData inclusion, archive and recorded path;
- global Safari inclusion, archive and recorded path;
- system-global inclusion;
- shared-database inclusion.

Malformed values return a bounded `PXBackupManifestV4ErrorDomain` error. A final public-boundary catch converts an unexpected Objective-C exception into a generic v4 field error; it is defense in depth after the explicit typed gates rather than the primary validation mechanism.

## Validator type safety

`PXBackupManifestValidator.m` now validates/extracts runtime strings before comparing:

- schema identifier and digest algorithm;
- publication protocol and content state;
- backup mode and bundle identity;
- artifact name, path and digest;
- archive checksum;
- component archive/method/path fields;
- all four artifact policy values.

All v4 request and inclusion fields use the exact-CFBoolean helper. Integer `0`/`1`, strings and collection objects are not accepted as Booleans.

The public v4 dispatch is wrapped by a final exception boundary that returns a validator `NSError`; legacy v2/v3 dispatch remains outside that catch and byte-identical in behavior.

## Error contract

The eager placeholder error at the beginning of v4 validation was removed.

The validator now uses an on-demand fallback only when a reached failure path has not already produced a specific error.

Expected contract:

```text
valid v4:
  return YES
  error nil

malformed v4:
  return NO
  error nonnil
  no Objective-C exception escapes
```

The main v4 validation function contains no reachable bare failure return that intentionally omits the error contract.

## Parent TASK-3.6 non-regression

The corrective commit preserves:

```text
public v4 API and 14 error codes
exact 23 input keys
exact 33 root keys
canonical lowercase backup UUID
bounded immutable snapshot
relative artifact name/path
path == name
persisted policy strings
canonical artifact order
one required ApplicationData first
count/size/checksum derivation
exact declaration-reference coverage
v4 excluded Preferences empty archive
factual option arrays
v2/v3 legacy validation
unknown positive-version manager boundary
manager code 107 fallback
writeToFile:atomically: temporary TASK-3.6 boundary
```

Protected source diff is zero.

## Evidence

The report declares:

```text
builder malformed cases:   166
validator malformed cases: 262
explicit scenario rows:    428
```

Strict Objective-C frontend gates for builder, validator and temporary exception harness passed. The Windows workspace cannot link or execute Foundation/Objective-C runtime harnesses, so native exception replay remains pending GitHub Actions or target-device execution.

Owner continuation is accepted as build-status confirmation. No source evidence contradicts that signal.

## Independent gates

```text
git show --check:                     PASS
baseline-to-HEAD diff --check:        PASS
implementation scope:                 PASS
protected production diff:            0
builder exact-Boolean helpers:         1
validator exact-Boolean helpers:       1
builder unsafe raw Boolean sites:      0
validator v4 unsafe raw Boolean sites: 0
builder unsafe raw string compares:    0
validator v4 unsafe raw compares:      0
validator eager placeholder block:     0
v4 23-key input contract:              retained
v4 33-key root contract:               retained
v4 exact reference coverage:           retained
report scenario rows:                428
new trailing whitespace:               0
new NUL bytes:                         0
```

## Final verdict

TASK-3.6A corrects the malformed-type exception-safety blocker without changing the accepted v4 schema or manager integration.

TASK-3.6A is **COMPLETED**. TASK-3.6 is **COMPLETED**. TASK-3.7 may proceed.
