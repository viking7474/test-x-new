# Patch 4C.2H6T — Storage cache, load/save ordering and display batch

2026-11-06. User confirms the H6L native follow-up build passes and asks for a
larger implementation batch. Baseline: ef12b3b. Read the complete StorageManager
implementation/header, its source ownership helpers, consumer display/generation
flows, source-contract scanners and existing native fixtures. This batch groups
eight related changes rather than advancing one accessor per build.

## Findings and implemented changes

These findings distinguish unsafe source patterns and deterministic overlapping
operations from an observed device incident. New native scenarios specify the
reproduction; they have not been executed on this Windows host. No device crash
frequency, retained-byte count or measured speedup is established.

| Priority / severity | Location | Problem, practical consequence and change |
| --- | --- | --- |
| P1 / High potential | StorageManager cache, scalar getters, setters, adoption, loadFromProfile | Reads/copies raced mutable dictionary edits and root replacement. A concurrent load could expose an empty/prefix record, unsafe dictionary access or an object lifetime race. Own state now uses immutable roots, retained capture under a short monitor and conditional pointer replacement. Previous roots are kept alive until outside the monitor. Reproduce with overlapping adoption/read operations; the new fixture specifies 256 concurrent replacements/observations. |
| P1 / Medium | adoptCommittedStorageInfo, setStorageScalar, load preparation | Root-only copying shared mutable owned scalar strings; unsupported roots could poison later dictionary operations. Freeze TotalStorage/FreeStorage/FilesystemType strings while preserving numeric types, invalid legacy field read policy and shallow unrelated metadata. Reject unsupported root/scalar inputs. Nil adoption keeps empty reads; a later setter can rebuild that cache instead of silently messaging nil. Mutable-string mutation after adoption/setter is covered. |
| P1 / Medium | loadFromCurrentProfile, loadFromProfile, defaults | Older lookup/read/default preparation could overwrite a newer explicit load or committed adoption. Claim an epoch before canonical lookup and retain it through private loading/default helpers; publish only while current. The A/B reversed-loader, read-time adoption and default-provider reentry cases specify this ordering. |
| P1 / Medium | setters, saveToCurrentProfile, persistStorageRecord | Setters autosaved by rereading whichever cache existed after lifecycle/target lookup. A save could write a newer operation's cache rather than its own candidate. Setters now pass the frozen record they published. Explicit saves retain an entry root/revision before acquisition, copy only after ownership succeeds and reject supersession before lookup/copy/staging. Target remains fixed once selected. The fixture changes cache during acquisition and copying. |
| P1 / Medium | commitDisplayStorageInfo preparation | Input methods or target/cache copying could reenter and update cache; an older display operation could then claim over it. Observe revision before foreign input work, copy the input root before reading/fixing scalar values, retain standalone admission and conditionally claim only after lifecycle acquisition. Recheck before source staging. Reentrant input copy, acquisition adoption and pre-stage adoption are covered. |
| P1 / Medium | commitDisplayStorageInfo post-commit | Unconditional cache assignment after source acknowledgement could overwrite a newer adoption. Publish the detached staged packet only if its revision still matches; return source success even when cache publication is skipped. Both a controlled backend and the existing real SourceStore fixture specify adoption at commit-written, verifying that source success and the newer cache survive together. |
| P1 / Medium potential | preparation/source callbacks, cache replacement | Plain ARC abnormal exits could retain named records/inputs and inline method-argument block copies. A discarded dictionary could also release foreign metadata while the cache monitor was held. Own helper/flow parameters and records have finally cleanup; method-argument callbacks occupy named strong slots; capability invalidation precedes callback/reference cleanup. Old-root release occurs outside the monitor. Borrowed throwing mocks check weak owner/target/token/callback roots after pool drain; copy/dealloc probes require another-thread cache access to complete. |
| P2 / Low–moderate relative cost | stale load/default work; IdentifierManager storage display | Known-superseded work still performed subsequent target file reads or generation, and display separately read total/free from potentially different revisions. Stale work now exits before those subsequent operations. Display uses one currentStorageInfo snapshot when the provider supports it, with the existing legacy getter branch only when that API is absent. Controlled counters verify skipped reads/providers; display tests change provider state before return and verify one pair observation. |

The helper methods and complete storage wrapper bodies are extracted unchanged
into the existing native fixture fragments. The new fixture compiles those same
bodies, including the persistence/display backend methods, against controlled
collaborators. Scanners follow persistStorageRecord:revision:profileID:current:error:
where the actual staging now lives; they still require lifecycle ownership and
the source write. No transaction assertion was replaced with a wrapper-name test.

## Protocol and behavior

The epoch is per instance and protected with the cache root. It records newer
load/update intent, not a globally committed source revision. A load claims before
lookup. Setter/adoption input preparation observes first, then conditionally
claims; invalid inputs do not supersede valid work. Display retains its standalone
admission before any ownership attempt, so nested source staging still poisons
the outer transaction instead of masquerading as commit success.

The short cache monitor covers scalar epoch operations and retained pointer
capture/replacement. Copying, dictionary mutation, field conversion, providers,
model DB work, file access, source/lifecycle ownership and logging execute outside
it. No spin/retry loop, dispatch queue, timer, polling, class cache or TTL is added.
Old-root destruction occurs outside the monitor; foreign destructor behavior and
externally held locks remain outside the manager's guarantee.

Normal policies retained:

- Canonical selection-file authority for current saves, one target under lifecycle,
  explicit-target saves and existing root-only legacy profiles with no identity
  child. Missing/busy/pending/invalid namespaces are not recreated.
- Setter cache-first publication before one autosave. Source failure does not
  roll the candidate cache back. Nil removes a field and saves; numeric legacy
  scalar types remain numeric in records. No new number/format normalization.
- Missing-file defaults and their field-clearing/unrelated-metadata policy,
  model-aware capacity tiers and immediate-repeat avoidance, marketing units,
  boundary/overflow checks and filesystem spelling. Singleton and preference-flag
  method bodies are preserved; init only changes its empty root to immutable.
- Display's source-first acknowledgement, allocation before acknowledgement,
  same filesystem ownership/removal semantics, and no notifications. A newer
  operation can leave committed source and cache different; that is reported as
  committed success rather than an aborted write. No stale rollback is attempted.
- IdentifierManager canonical/sidecar/captured authority and generated/final display
  fallback remain. Snapshot miss/malformed/throw never mixes in legacy getters
  from another observation; the existing generation/final fallback can still run.
  Providers without currentStorageInfo keep their old individual getters.

Superseded operations stop without retry. A load can return NO even if it read a
record when newer work prevented adoption. Display/save supersession reports
storage-display error 3. Previously undefined concurrent outcomes are now bounded;
this is not a guarantee that every competing per-field update is merged. An
explicit newer reload can supersede a cache-first candidate. Once source staging
has been accepted, later cache work does not retroactively cancel/rollback it.
No cache monitor spans the comparison and source I/O as a global transaction.

Private token-preserving paths replace virtual calls through public save/load
wrappers for automatic setter/current-load flows. No production StorageManager
subclass or override of these wrappers was found in this repository. External
subclasses relying on those callbacks are not promised identical dispatch; using
the old wrappers would discard the fixed record/load token. Direct public calls
retain their selectors. Custom copy conventions and concurrent mutation during
copy, nested mutable metadata, direct private/KVC edits, providers' own thread
safety and other instances/processes do not join this cooperative protocol.

## Performance and scope

Uncontended immutable-root reads add a short monitor and ARC retention; ordinary
NSDictionary copy normally reuses its immutable root. There is no new disk or
generation work on getters. The display now requests one root rather than two
field observations. Expected incremental read cost is low; no hot-path frequency
or benchmark is claimed. Mutation uses copy-on-write and scalar freezing, adding
allocations with expected moderate relative cost on the write path to remove
mutable collection races. Stale cancellation avoids subsequent disk/provider work
only when supersession is established; its frequency remains unmeasured.

The shared common implementation applies to rootful and RootHide. StorageHooks,
BatteryHooks, WiFiHook, captured reader branches, constructors/install/scope,
bootstrap, Makefile, dependencies and package scripts are untouched. RootHide's
iOS 15.8.8/AIDA64 fix remains outside the diff. The manifest adds the real private
staging entry point and clarifies this coverage without advancing the existing
4C.2H5S-partial rollout marker. Full source authority, mirror convergence, other
writers and later audit patches remain incomplete.

## Verification

- New PXStorageManagerCacheTests uses the exact existing full storage fragment,
  with controlled files, model providers and synchronous ownership/source helpers.
  It covers frozen/numeric/nil/unsupported inputs, saved/default load ordering,
  current lookup cancellation, fixed save entries, copy/input reentry, pre-stage
  supersession, post-commit adoption, ten injected display/save/load exceptions,
  weak graph/callback cleanup, monitor boundaries and 256 concurrent pair reads.
  It does not model actual filesystem recovery, transport or private iOS APIs.
- Only captured callbacks are subjected to deallocation assertions: display's
  capture-free resolver can be a permanent global block. Save resolver captures
  and source body captures are observed weakly. Mocks borrow throwing parameters
  and explicitly clean their own roots to avoid a stand-in creating callee leaks.
- The real artifact fixture retains namespace, busy/pending, rollback, marker and
  original storage boundary tests, adding a real commit-written cache race and
  settling its baseline afterward. The Identifier reader fixture adds modern
  snapshot validity/exception/single-pair and legacy-provider cases.
- Local regression: 62/63 Python suites and 4/4 Node suites passed; the established
  Git Bash mkdir /c/Users/ADMIN permission failure remains in Keychain retirement
  (4 failures, 1 error, 1 skip). Source hardening and RootHide static/package checks
  (metadata/negative controls 6/6) pass. git diff --check passes.
- Four fragment generators completed, with unique exact storage bodies/helper
  declarations and the exact new display helper. Fourteen negative source controls
  rejected broken capture/publication/admission/freeze/cleanup/cancellation and
  missing post-commit or display assertions. Unrelated IdentifierManager flow and
  storage singleton/conversion/preference method bodies were preserved exactly.
- Captured recipes include four storage-manager-cache and four Identifier reader
  variants: rootful/RootHide x plain ARC/ARC exception cleanup at -O0. Existing
  real-source fixture recipes remain enrolled. Compiler/binary invocations were
  captured, not executed.

Foundation/xcrun/Theos and an iOS device are unavailable on Windows. New native
assertions, package builds and device behavior require macOS CI/device execution.
No native/build/device pass, performance benchmark, commit, push or deployment
is claimed for H6T.
