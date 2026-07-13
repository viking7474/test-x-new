# TASK-1.3 Review — Canonical Destructive Path Validator

## Review result

**ACCEPTED**

TASK-1.3 is accepted after source review and project-owner build confirmation.

Build status recorded by coordinator:

```text
PASSED — reported by project owner
```

The agent report itself correctly remains marked `GitHub Actions: PENDING`; the owner confirmation is recorded here as the authoritative build gate.

## Reviewed artifacts

```text
PXDestructivePathValidator.h
PXDestructivePathValidator.m
docs/backup-restore-hardening/reports/TASK-1.3-REPORT.md
```

Repository state reviewed:

```text
HEAD: a2f5de8
TASK-1.1 and TASK-1.2 tracked and clean
TASK-1.3 artifacts untracked and isolated
```

## Contract verification

The public API and error enum match the accepted task specification:

- one exported error domain;
- eleven exact error codes;
- one subclassing-restricted validator class;
- one public method returning a nullable canonical `NSString` path;
- no boolean deletion-authorization API;
- no custom base input or configuration surface.

The validator clears a supplied error pointer at entry and returns no raw or partially validated path on failure.

## Fixed-base and raw-path policy

The implementation maps all supported data-container kind/root combinations to fixed bases:

- application and extension data;
- App Group data;
- PluginKit data;
- rootful and rootless layouts.

Application bundle containers have no kind or base mapping.

The model path must equal the selected fixed base plus the exact UUID before filesystem canonicalization. This rejects rootful aliases, wrong-kind bases, nested descendants and sibling targets.

## Canonical containment review

The implementation:

- performs `lstat` on the exact candidate before `realpath`;
- rejects candidate symlinks and non-directories;
- canonicalizes base and candidate independently;
- requires the canonical candidate parent to equal the canonical base exactly;
- requires the canonical final component to equal the exact UUID;
- does not use prefix matching as containment authorization.

This closes sibling-prefix and deeper-descendant ambiguity.

## Filesystem identity and mount boundary

The source retains the initial candidate `lstat` identity and compares it with canonical candidate `stat` identity.

It also requires candidate and canonical base to share the same device, rejecting a separate mounted child target.

The `mobile` UID is resolved deterministically with `getpwnam_r`; there is no fallback to current UID, root UID or a hard-coded numeric value.

Candidate ownership and world-writable mode checks match the task contract. The canonical base is also rejected when world-writable.

## Metadata safety and exact identity

The validator accepts only:

```text
.com.apple.mobile_container_manager.metadata.plist
MCMMetadataIdentifier
```

The metadata object must be a same-device, mobile-owned, non-world-writable regular file and not a symlink. Its canonical parent must equal the canonical candidate exactly.

For application, extension and PluginKit data, the live identifier must exactly match both model identifiers.

For App Group metadata:

- an exact string is accepted;
- an array must contain exactly one exact occurrence;
- zero occurrences fail as identity mismatch;
- duplicate exact occurrences fail as invalid metadata;
- non-string entries are not treated as matches.

No fuzzy, prefix, suffix, substring or case-folded identity matching is present.

## Final recheck and return

After reading metadata, the implementation performs final `lstat` checks for candidate and metadata and requires device/inode identity to remain unchanged.

The canonical candidate string is returned only after those final checks.

This reduces the validation-window TOCTOU risk while preserving the documented limitation that a future destructive caller must validate immediately before use.

## Scope verification

Search and protected-file checks confirmed:

- no existing production source references the validator;
- no Clear caller consumes its output;
- no deletion API is present;
- no permission mutation is present;
- no shell, command runner or process API is present;
- no existing production file changed;
- `PXResolvedContainer` and `PXDataContainerResolver` remained unchanged;
- `git diff --check` and new-file whitespace checks passed.

## Remaining limitations

The validator is still unused, so legacy destructive callers remain unchanged.

The final inode checks cannot detect in-place content or mode changes that preserve inode identity after the corresponding checks. Future integration must invoke validation immediately before the destructive operation and must use the returned canonical path rather than the raw model path.

Descriptor-bound validation and deletion are not part of this task.

## Coordinator decision

TASK-1.3 is `COMPLETED`.

TASK-1.4 may open with a narrow behavior-removal scope:

- remove all active writes into application bundle containers;
- preserve read-only bundle discovery and inspection;
- preserve public selector compatibility;
- do not yet migrate data-container Clear paths to the resolver/validator;
- do not start typed Clear request/result work.
