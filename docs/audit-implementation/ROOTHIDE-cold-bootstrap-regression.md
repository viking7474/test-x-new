# RootHide: snapshot readiness during hook bootstrap

Reported device: iOS 15.8.8, AIDA64. Initially the app reported real values;
after the bootstrap patch, the user confirmed "Đã ổn" on 2026-10-27.
This records a user-confirmed recovery on the reported device, not a complete
compatibility matrix or an independently captured loader/lock trace. Comparison baseline:
`da37bfc9cc68994458804c3e536cfad3145dd8ad`; reviewed HEAD:
`0b87c1e002ba7f9b2782c2baf7f3d93b100fd720`. The bootstrap patch is in
`a52ca50`.

## Source findings and limits

The installed main filter template is unchanged from the working baseline.
RootHide still stages the main tweak in `/usr/lib/TweakInject`. Bridge retirement
removes the retired bridge's exact filenames, not the main tweak. These source
comparisons do not establish which files were installed on the reported device.
Changing a package dependency alone cannot establish whether injection works.

The captured reader introduced a concrete bootstrap failure path:

1. A constructor calls `PXBootstrapDecisionForCurrentProcess`.
2. `PXPrimeRuntimeSnapshotReader` schedules the first read on another queue and
   waits at most one second. Its result is ignored by the scope adapter.
3. A pending/invalid view produces a denied scope. Constructors that return here
   have no hook-installation retry when the queued load later completes.
4. Initial identity handler registration also invalidates the view and starts a
   worker, creating a second readiness dependency before subsequent constructors.

A slow worker suffices to reach this failure path. During image/class
initialization there is an additional potential lock dependency if worker work
needs initialization owned by the constructor thread. No device trace yet proves
that this additional dependency occurred in AIDA64. The previous synchronous
loader did not require worker progress for its first decision.

The old `primed` flag also meant "the refresh group completed", including invalid
input, rather than "a valid snapshot is ready". It did not itself make invalid
snapshots enabled; validation still denied them.

## Cause and maintenance constraints after device confirmation

The source-level defect is a mismatch between asynchronous data readiness and
one-shot hook installation: a temporary missing snapshot was used as a final
constructor decision. A worker completing later updated data, but did not rerun
the skipped hook installation. RootHide exercised this captured-reader bootstrap;
rootful kept its live-file reader path, explaining why the regression could be
specific to RootHide even though both packages compiled successfully.

The reported recovery after inline bootstrap supports this readiness diagnosis.
It does not identify the exact reason for the worker delay: dyld/ObjC lock
contention remains a possible mechanism, not a measured deadlock. No supplied
probe/stack trace establishes that the dylib previously failed to load. Therefore
do not describe this as a proven ElleKit failure or dependency-only fix.

Preserve these constraints in subsequent patches:

1. Prime before `PX_RUNTIME_READ_OPERATION`. Lexical scopes intentionally inherit
   their captured view, including nil; loading after entering the scope does not
   repair that operation's decision.
2. First identity handler registration must not leave an avoidable asynchronous
   gap before later constructor gates. Bootstrap preparation uses the same
   producer ownership and validation rules as background refresh.
3. Do not restore a constructor dependency on worker completion or merely extend
   its timeout. A larger timeout still cannot guarantee readiness or retry skipped
   installation, and may increase launch latency.
4. Keep disk reads/preparation out of hot capture operations; synchronous work is
   limited to explicit bootstrap paths. Do not weaken scope or malformed-data
   rejection to make installation appear successful.
5. Keep constructor integration coverage and separately verify actual hook
   behavior on-device. Build/source success alone did not expose this regression.

## Patch

- Explicit cold priming claims the reader's existing producer slot and loads on
  the bootstrap caller if idle. It never steals an active worker or waits for it.
- Initial identity preparation can use the same inline producer path before
  bootstrap returns. Later constructors capture the prepared publication.
- The WebKit metadata bootstrap uses inline priming too.
- `capture` remains nonblocking. Notifications and on-demand refreshes remain
  asynchronous. No timer, broad injection target, scope bypass or fallback to
  another source was added.
- Publication metadata is updated before releasing the producer slot, so an
  inline producer and a queued producer cannot race epoch/revision bookkeeping.
- A thread-local producer stack rejects recursive waits on inline loaders too.

This is a bootstrap readiness fix, not proof that the reported device's loader,
filter, daemon publication and permissions are all healthy. First bootstrap and
first identity preparation perform synchronous work; this restores a startup
readiness guarantee at the cost of cold-start I/O. It adds no parsing to hot
capture operations. The initial identity registration currently performs a second
load, as covered by the integration fixture.

## Verification

`python3 scripts/test_runtime_snapshot_reader.py --native` now runs the reader
fixture and a separate RootHide constructor integration fixture, each three times.
The latter compiles the actual process-reader bootstrap wrappers extracted from
`PXRuntimeSnapshot.m`, the actual `PXScope.m`, reader and lexical scope engine.
Only storage, process classification and identity projection are fixtures. A
recursive initialization lock makes an off-thread cold load fail deterministically.
Checks cover the first decision, prepared projection, 40 later constructor gates,
scope/master revocation and invalid snapshots. They do not emulate ElleKit, iOS
sandboxing or actual identity database loading.

Local Windows validation: 59/60 Python regression suites and 4/4 Node suites passed;
the remaining bridge migration shell suite fails because the local shell cannot
create `/c/Users/ADMIN` in its fixture environment. Source hardening, RootHide build
contracts and package metadata checks also passed. Native Foundation/CI logs were
not supplied in this conversation. The user has now confirmed recovery on the
reported iOS 15.8.8/AIDA64 setup; other devices/processes remain unverified.

## Device confirmation

For future regressions or broader validation, manually close and reopen the target
app and inspect fresh events (timestamp and PID must match this launch):

- `tweak_load_probe.plist`: early dylib load signal.
- `tweak_bootstrap_probe.plist`: actual role, reason and capability decision.
- `hook_install_probe.plist`: reached installation stages and missing data/symbols.
- `runtime_snapshot_debug.plist`: daemon publication success, global commit,
  mirror distribution, errors and counts.
- `filter_daemon_debug.plist`: installed filter and daemon diagnostics.

These files are under `/var/mobile/Library/TLinkIOS` in the iOS namespace, or
`/rootfs/var/mobile/Library/TLinkIOS` from a RootHide bootstrap shell. Do not treat
an old event from the working package as verification of the new package. Absence
of a probe alone does not prove absence of injection: the daemon/probe delivery
must also be working. If the load probe is fresh but bootstrap denies, investigate
snapshot/scope; if bootstrap allows but stages/data are missing, investigate that
specific stage. Retain the distinction between user-confirmed recovery, native
fixture results and a probe/stack trace that proves the exact runtime mechanism.
