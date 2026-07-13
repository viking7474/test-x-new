# TASK-1.5 Review — Typed `PXClearRequest`

## Verdict

**ACCEPTED**

TASK-1.5 satisfies the model-only contract and may be marked `COMPLETED`.

## Reviewed implementation

- `PXClearRequest.h`
- `PXClearRequest.m`
- `docs/backup-restore-hardening/reports/TASK-1.5-REPORT.md`
- commit `24cde1e`

## Source findings

The request model has the required closed five-bit scope set:

- `PXClearScopeApplicationData`
- `PXClearScopeExtensionData`
- `PXClearScopeAppGroups`
- `PXClearScopePluginKitData`
- `PXClearScopeKeychain`

There is no application-bundle or receipt scope. `PXClearScopeKnownMask` and `PXClearScopeDefaultMask` are exact unions of the five approved bits.

The class exposes exactly three readonly values:

- exact bundle identifier;
- requested scope mask;
- deep-clean intent.

The designated initializer rejects invalid runtime types, empty or whitespace-only identifiers, embedded NUL, path/wildcard characters, malformed dot components, non-ASCII characters, zero scopes and unknown scope bits. Accepted identifiers and scope subsets are preserved without normalization or mask repair.

Immutability is explicit:

- subclassing restricted;
- private ivars;
- no setter or `readwrite` redeclaration;
- copied identifier;
- `copyWithZone:` returns `self`;
- equality and hash include all three fields.

The implementation contains no filesystem, process, resolver, validator, keychain, UI, user-default or destructive behavior. Existing production source contains no references to the request model.

## Verification

- source scope bits: 5;
- public properties: 3;
- application-bundle/receipt scope: 0;
- `readwrite`: 0;
- setter methods: 0;
- prohibited subsystem tokens: 0;
- existing production references outside the two new files: 0;
- source/report trailing whitespace: 0;
- `git show --check 24cde1e`: passed;
- current working tree at review start: clean.

## Build gate

The task report records GitHub Actions as pending. The project owner stated the task was completed and continued the gated workflow, so the build is recorded as:

```text
PASSED — reported by project owner
```

No local Objective-C/iOS runtime result is claimed by this review.

## Traceability note

Commit `24cde1e` includes accumulated TASK-1.3 and TASK-1.4 artifacts in addition to TASK-1.5. This reduces per-task commit isolation, but it is not a TASK-1.5 source blocker because:

- the task-owned production files are independently identifiable;
- prior-task source had already been reviewed and accepted;
- the final working tree is clean;
- the request implementation itself is isolated and has no caller integration.

Future tasks should preferably use one commit per task.

## Remaining boundary

`PXClearRequest` records intent only. It does not define per-component outcomes, overall completion semantics, container resolution, canonical authorization or destructive execution.

TASK-1.6 may now define the immutable structured result contract. Existing Clear callers must remain unchanged until the dedicated migration tasks.
