# Patch 4C.2H6V — Uptime validation, cache ordering and exceptional lifetime

2026-11-06. Baseline b258427 plus the uncommitted H6U batch. The user said
"tiếp tục" while H6U was being closed, so H6V joins the same pending-CI batch;
there is no user-confirmed H6U build result. Read the complete UptimeManager
implementation/header, uptime stage and pure preparation, existing native
fixtures and the IdentifierManager/BootTimeHooks call paths before changing them.

## Findings and implementation

These are source defects and potential malformed-input, concurrent or exceptional
failures, not newly observed device incidents. Native reproductions below are
implemented fixtures awaiting macOS execution.

| # | Priority / severity | Location | Problem, effect and concrete change |
|---|---|---|---|
| 1 | P1 / High potential | UptimeManager scalar/date readers, setters, consistency validator | Unsupported containers could receive doubleValue/date selectors; NaN/Infinity could pass sign checks and poison cached arithmetic or a later date conversion. Require NSString/NSNumber and finite scalar output, or a finite NSDate. Retain NSString doubleValue prefix parsing, existing file fallback order, read-only sentinels and inclusive one-second consistency tolerance. Fixtures inject arrays, dictionaries, NSNull, NaN and both infinities. |
| 2 | P1 / Medium potential | Profile-specific readers and generation adapters | Unchecked or mutable path inputs could fail selector dispatch or change between provider/file operations. Validate nonempty string and copy once for the operation; retain canonical identity validation for writes and legacy non-canonical read acceptance. Invalid roots stop before file/provider/source work. No new absolute-path grammar or directory creation. |
| 3 | P1 / Medium potential | PXUptimePreparedPacket / PXStageRuntimeUptime | Mutable known child fields could change between preparation and paired staging, and exceptional stage exits left retained partial dictionaries/parameters to implicit ARC cleanup. Freeze required date/value/seconds fields before transaction callbacks; preserve unrelated shallow metadata and raw numeric spelling. The C stage checks required finite date/scalar values and owns explicit cleanup for identity/maps/paths/input parameters. Tests mutate caller fields before source entry and on the first transaction read, and fault the second write. This is type/finiteness validation, not normalization of arbitrary inconsistent provider tuples. |
| 4 | P1 / High potential | bootTimeValue / uptimeValue / cacheTime / error storage | Independent nonatomic properties allowed overlapping updates and mixed observations. Retain/capture the tuple under one short monitor and replace its fields together. Keep displaced object roots alive through unlock, then release outside it; error userInfo deallocation may reenter manager code. A 256-operation adoption/capture fixture checks tuple arithmetic without I/O, plus a destructor/worker handshake checks release outside the monitor. |
| 5 | P1 / High potential | generation, adoption, setters and error publication | A prepared generation or its post-commit adoption could overwrite a newer cache/error. Observe an epoch before foreign preparation; conditionally claim after preparation/admission, recheck before source staging and conditionally publish after ownership release. Newer valid adoption/setter intent supersedes old local publication. An acknowledged source commit remains successful even if its cache publication is skipped. Both controlled callbacks and a real SourceStore commit-written checkpoint cover this ordering. |
| 6 | P1 / Medium correctness guard | Lifecycle admission and epoch receipt | Claiming an epoch before a failed/busy acquire would revoke the owner currently holding the lease, including reentrant generation. Claim only after successful acquire; a busy inner call cannot cancel the outer source write. Invalid path/busy errors are conditional observations; they do not advance the epoch. This is a constraint on the new ordering design, not a claim that the baseline already had an epoch bug. |
| 7 | P1 / Medium potential | Generation/read/adoption scopes and callbacks | Plain ARC exceptional unwind cannot be treated as proof that every strong local/argument-block capture is released. Hoist owned roots, name resolver/source blocks and clear them and retained parameters in finally. Invalidate lifecycle ownership before error logging/publication and before dropping captured roots. Six fault scenarios observe weak manager/input/token/capability/transaction/block roots after pool drain in both ARC modes. Existing generation catch policy and reader exception propagation remain. |
| 8 | P1 / Medium edge case | prepareConsistentUptimeInfo / debug sysctl adapter | A success return alone did not validate the returned timeval size or plausible finite nonnegative real delta. Require a full timeval, positive boot seconds and finite nonnegative elapsed time before passing hasRealUptime. Short/future/failed output follows the existing unavailable-real-time branch. The pure random generator and its minimum/clamp policy are unchanged. |
| 9 | P2 / Low correctness | debugSpoofedUptimeInfo / lastError | Multiple property observations could format a mixed cache description. Format from one retained boot/seconds/clock capture outside the monitor; lastError returns one retained instance observation. This is not a per-call ACK, a profile-tagged cache or one filesystem snapshot across separate getters. |
| 10 | P2 / Low | Initialization and dead constants | The private concurrent queue was created but had no caller; three dictionary constants were unused. Remove the unused queue allocation and constants. No dispatch scheduling or thread is removed; no CPU/latency saving is measured. |

## Preserved behavior and limitations

Source/lifecycle engine code, namespace proof, pending-deletion checks, existing
identity requirement, rollback and marker acknowledgement are unchanged. Provider
preparation remains outside the source gate and inside acquired lifecycle scope.
Ownership is released before cache publication/logging. The stage remains a
composable transaction helper without acquiring lifecycle ownership or notifying.

Valid reads keep boot-sidecar -> elapsed-sidecar -> IDs precedence for uptime,
and boot-sidecar -> IDs precedence for boot date. generateIfMissing:NO never
adopts cache, generates or persists; default readers retain the 12-hour fallback.
The legacy generateUptime/currentUptime/generateBootTime/currentBootTime stubs
remain unchanged. Public generation wrappers retain their existing call pattern,
including a possible second generation attempt through an auto-generating getter
on failure. No claim is made that this retry or broader synchronous I/O is fixed.

Normal setters preserve the old prior-error policy, and finite future boot dates
still permit a negative cached elapsed value. Invalid setters record existing
1001/1002 errors without poisoning the prior tuple; valid adoption clears error.
Minimal/nil adoption records retain legacy nil/zero behavior. Invalid adoption
roots/values are ignored without claiming newer intent. No new positivity/range
rule is imposed on finite prepared/adopted values. Copies detach required known
fields; unrelated metadata is shallow and arbitrary foreign concurrent mutation,
malicious subclasses, private KVC/ivar edits and callee-owned cleanup are outside
the guarantee.

Production uses public profile readers/preparation/adoption via IdentifierManager;
BootTimeHooks' legacy branch uses the profile readers. No in-repository private
per-field KVO consumer was found. The new internal publication bypasses private
per-field setters, so external overrides/KVO observing those private properties
are not preserved. The public ABI remains; nullable declarations now reflect
actual profile-reader/preparation/lastError results. Separate getters still read
files independently, and other manager instances/processes/source writers are not
ordered by this per-instance epoch. Whole source/cache/profile consistency is
still partial. An update after staging admission may complete the older source
commit while preserving the newer local cache; no rollback of acknowledged source
success or atomic source/cache CAS is introduced.

## Performance and compatibility

Cache capture/publication adds a bounded monitor/retention cost (expected low,
unmeasured). No I/O, provider, copy, formatting or logging is performed inside it;
discarded roots release afterward. Debug formatting takes one capture. Immutable
NSDate/NSString copies normally retain existing values; mutable packet detachment
adds bounded allocations on the preparation/write path. Saved hits keep the same
file-read count; malformed values may require bounded fallback reads. There is no
new queue, timer, polling, IPC or network request and no benchmark claim.

Common manager/staging changes apply to rootful and RootHide. Every hook,
constructor, runtime captured branch, bootstrap/scope/install policy, package,
dependency, Makefile and the iOS 15.8.8/AIDA64 bootstrap fix is untouched. H6U's
"uptime stage preserved" and "UptimeManager separate" statements describe its
checkpoint; H6V intentionally changes them in this same pending-CI batch. The
manifest adds actual uptime/header/stage coverage and keeps 4C.2H5S-partial.

## Verification

- New exact-fragment PXUptimeBoundaryTests covers typed finite reads and fallback,
  setters, preparation, mutable inputs, direct C staging, provider/source/cache
  reentry and supersession, real sysctl-result adaptation, exceptional weak roots,
  coherent concurrent capture and deferred error-metadata release. Collaborators
  are controlled stand-ins with borrowed throwing arguments, not device APIs.
- Existing real SourceStore/lifecycle fixture retains its owned generation tests.
  Its cache assertion now overrides the actual tuple publication helper instead
  of an unused private per-field setter. A new commit-written adoption verifies
  the real acknowledged transaction cannot overwrite newer local cache.
- Five fragment generators complete; uptime helpers, stage, method bodies and
  unique declarations are exact production extractions. CHECK arity is validated
  for all five changed/new fixtures. Twelve new recipes across H6U/H6V cover
  Network/Carrier/Uptime x rootful/RootHide x plain ARC/ARC exception cleanup at
  -O0. Recipes were captured; compiler/binary calls were not executed.
- Source guards include epoch compare/claim/publication, deferred roots, typed
  finite preparation/staging and the real checkpoint assertion. Eighteen H6V and
  sixteen H6U in-memory negative controls are checked separately from runtime.
- Windows full regression: 62/63 Python suites, 4/4 Node suites; established
  Keychain retirement Git Bash mkdir /c/Users/ADMIN permission failure remains
  (4 failures, 1 error, 1 skip). Source hardening, RootHide static/package controls
  (6/6) and diff checks pass. Protected bootstrap/hook/package paths, legacy
  singletons/stubs, pure preparation, carrier seed/RNG and unrelated WiFi/Battery
  staging remain unchanged.

Foundation/xcrun/Theos/device execution is unavailable on this Windows host. H6U
and H6V native assertions and package/device behavior require macOS CI/device
verification; no native/build/device pass, benchmark, commit, push or deployment
is claimed. Full Patch 4 and later stages remain incomplete.

Native follow-up: H6U CI exposed a stack-literal capture-scope gap under plain
ARC. The Uptime resolver and source callback now finish construction in explicit
inner lexical scopes before the potentially throwing calls; named heap callbacks
and their finally cleanup remain. See the H6U native-follow-up section for user
CI evidence, compiler references, preserved behavior and verification limits.
The original Uptime exceptional-owner assertions remain enrolled in both ARC
modes and both package schemes; native results are still pending.
