# TASK-1.1 Coordinator Review — Immutable `PXResolvedContainer`

## Result

```text
Task: TASK-1.1
Source review: ACCEPTED
Build gate: PASSED — reported by project owner
Final status: COMPLETED
```

## Reviewed artifacts

- `PXResolvedContainer.h`
- `PXResolvedContainer.m`
- `docs/backup-restore-hardening/reports/TASK-1.1-REPORT.md`
- protected-file diff and repository source gates

At review time the TASK-1.1 source/report files were present as untracked working-tree files rather than a dedicated commit. Acceptance is based on full-file review and the project-owner build confirmation, not on a commit message or hash.

## Scope review

Accepted scope:

- exactly two new production files were added;
- no existing production source or Makefile was modified;
- no resolver, caller migration, filesystem authorization or destructive operation was introduced;
- the required report was created;
- TASK-1.2 and TASK-1.3 were not implemented.

## Contract review

The class contract matches the specification:

- `PXResolvedContainerKind` contains only application data, app group, extension data and PluginKit data;
- application bundle containers are not representable;
- root is explicitly rootful or rootless;
- the class is subclassing-restricted;
- the class conforms to `NSCopying` only;
- all six public properties are readonly;
- `init` and `new` are unavailable;
- one failable designated initializer exists;
- no setter or readwrite redeclaration exists.

## Validation review

Accepted initializer behavior:

- rejects invalid kind/root values;
- performs runtime `NSString` validation;
- rejects empty strings and whitespace-only identifiers;
- rejects embedded U+0000 in every string field without C-string conversion;
- requires exact case-sensitive equality between requested and metadata identifiers;
- requires a syntactically valid UUID string;
- preserves the caller's accepted UUID spelling;
- rejects relative, root, trailing-slash, double-slash and dot-component paths;
- requires `lastPathComponent` to equal the UUID exactly;
- performs no filesystem access or canonical path authorization.

## Immutability and value semantics

Accepted implementation details:

- state is held in private ivars;
- all accepted string inputs are copied;
- no mutation method is exposed;
- `copyWithZone:` returns the immutable receiver;
- `isEqual:` compares all six fields;
- `hash` incorporates the same six fields.

## Safety boundary

`PXResolvedContainer` is an immutable identity snapshot, not deletion authorization. It does not prove:

- existence;
- canonical location;
- absence of symlink or mount redirection;
- ownership or permissions;
- membership in a destructive-path allow-list.

Those checks remain reserved for TASK-1.3. No existing destructive caller may consume this type before the exact resolver and canonical validator are accepted.

## Verification

The following checks were reviewed:

- protected existing source diff: clean;
- `git diff --check`: passed for tracked files;
- `git diff --no-index --check` for both new source files: no whitespace errors;
- no existing production reference to the new type;
- no filesystem API in the model;
- no fuzzy identifier matching;
- no serialization or mutable-copying support;
- no application-bundle enum value.

LF/CRLF warnings are working-tree line-ending notices and are not content errors.

## Remaining risks

- The accepted task is not isolated in a dedicated commit at review time.
- Runtime behavior of Foundation UUID parsing depends on the target OS implementation.
- The candidate path remains intentionally non-canonical until TASK-1.3.
- Existing fuzzy resolvers and destructive callers remain unchanged.

## Decision

TASK-1.1 is accepted. TASK-1.2 may introduce a standalone exact application-data-container resolver that produces `PXResolvedContainer` values. It must not migrate `AppDataCleaner` or authorize deletion in the same task.
