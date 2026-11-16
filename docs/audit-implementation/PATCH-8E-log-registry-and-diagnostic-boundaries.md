# Patch 8E — Log-once registry and diagnostic sink boundaries

Date: 2026-11-15. Baseline `20382f4` (Patch 8D), whose build the user confirms
passed. This batch covers the shared log-once registry, primary logger, error
recovery logger and DB logger together. It implements diagnostic correctness and
exception boundaries; it does not complete Patch 8, logging policy or profiling.

## Findings and changes, in priority order

No new Critical finding is established. A code-proven failure branch is distinct
from a potential exception/reentry problem; native fault-injection fixtures must
still compile and run in CI. Relative costs below are qualitative, not measured.

| # / Priority / Severity | Location and evidence | Change and expected impact |
| --- | --- | --- |
| 1 / P1 / High potential crash | `common/TLinkIOSLogging.m`, former asynchronous body in `PXAppendToLogFile`: path resolution, attributes, rotation, date formatting and first-file writes were outside its seek/write catch. An exception on that queue cannot be caught by the submitting `PXLog`. | `PXWriteQueuedLog` contains the entire optional worker operation, closes acquired handles in finally and restores admission. Inject directory/attributes/open/seek/write/close failures, then submit another record. Prevents an optional diagnostic exception escaping GCD; normal per-record I/O remains. |
| 2 / P1 / Medium actual data-loss branch | `common/DBDebugLogger.m`, `PXDBLog`: when an existing file could not be opened for append, the old fallback atomically rewrote it with the new line. A transient append-open failure followed by a successful replacement could discard all history. | Drop that record on nil append handle and preserve existing bytes. The fixture injects nil open and compares bytes before/after. This deliberate failure-path behavior correction avoids destructive fallback; it does not promise durable logging. |
| 3 / P1 / Medium potential resource leak | `PXDBLog`: seek/write exceptions skipped `closeFile`; normal ARC cleanup is not guaranteed across exceptions in plain-ARC builds. | Encoding happens before acquiring a handle; inner finally attempts close once while still holding the DB monitor. An outer cleanup also handles earlier failures without double close. Fault injection counts close attempts. A throwing close does not prove the OS descriptor was closed; no unsafe second close is attempted. |
| 4 / P1 / Medium potential recursion/deadlock | `PXLog`, `PXLogError`, `PXDBLog` and the main worker call object formatting, defaults, file and error providers. Reentry could recurse or wait on an initializing once token; worker I/O callbacks could schedule an endless chain. | Per-thread admission precedes foreign validation/getters, formatter/regex/path once initialization and worker message access. Separate error admission permits its intended call into `PXLog` while bounding recursive recovery. Nested same-thread records are intentionally suppressed. Independent threads remain admitted. Low TLS/check overhead; no new queue or timer. |
| 5 / P1 / Medium potential deadlock | `common/PXRuntimeUtilities.m`, old claim/reset: mutable collection operations and reset string matching ran while an unfair lock was held, without finally unlock. Throwing/reentrant collection/string work could leave the registry unusable. | Immutable namespace-to-key-set packets; retain a basis under the short lock, prepare/hash/copy outside it, then compare-and-publish or retry. Keep the retired packet owned until after unlock. Validation/reentry faults must leave later claims usable. Cold insertion now copies the namespace map and changed bucket; this is a stability tradeoff, not a demonstrated speedup. |
| 6 / P1 / Medium potential exceptional lifetime | The logger/registry chains had unnamed or scope-local strong inputs, formatted strings, file providers and callbacks on exceptional paths. Plain ARC does not generally clean all strong locals during Objective-C unwinding. | Named roots with explicit finally cleanup, scoped callback creation, and autorelease pools for public sink work. Fixtures probe selected weak inputs, payload tokens and queued captures after pool drain under both ARC modes. This is not proof about every Foundation-internal allocation or every caller vararg. |
| 7 / P2 / Low actual registry API ambiguity | Old composite key `namespace + U+001F + key` conflated (`a`, `b<U+001F>c`) with (`a<U+001F>b`, `c`); reset of `a` also matched a longer namespace containing that separator. Existing production namespace literals do not demonstrate this collision in normal use. | Store namespace and key separately and reset by exact dictionary key. Fixture claims both pairs and resets only one. Both mutable inputs are detached before publication; concurrent mutation by an uncooperative caller remains outside the API's contract. |
| 8 / P1 / Low cleanup bug | Both variadic loggers called `va_end` only after successful `initWithFormat:arguments:`. A formatting exception skipped it. | Pair `va_start` with `va_end` in a dedicated finally. Formatting-error payload tests check recovery/admission and selected lifetime roots. Normal cost is negligible; no platform-specific corruption is asserted without evidence. |
| 9 / P1 / Medium potential capture leak | `PXAppendToLogFile`: a scheduling failure can unwind through a copied block that owns its message graph in a plain-ARC build. | Create the block in a nested scope, retain it in a named job slot, then submit and clear input/job in finally. Native recipe tests queued ownership until delivery and injected submission failure. Real GCD submission is not expected to throw ordinarily; this is a defensive callback boundary. |
| 10 / P1 / Medium potential initialization failure | Path, regex and DB formatter/monitor setup could throw inside `dispatch_once`. Letting exceptions cross the once callback has no useful retry/recovery contract here. | Catch inside those callbacks, clear partial candidates, finish once and suppress affected output when unavailable. Missing redactors never produce raw fallback. A nil DB monitor never becomes `@synchronized(nil)`. Isolated processes test path/regex/DB formatter initialization failures and subsequent calls. No automatic retry is added. |

All public logging and registry signatures stay unchanged.
`PXLogError` snapshots the code once; code 4001 still calls `synchronize`, while
3001/3002 and the Cocoa-domain observation remain no-ops. Errors in that optional
recovery are now contained. A malformed variadic call, unsafe pointer, fatal
signal or exception thrown during arbitrary object destruction is not made safe
by these Objective-C catches.

## Performance and retained policy

Warm registry claims retain a packet, look up one namespace/set and return
without composite-string formatting or publication. They still validate/copy
inputs, hash and use a short unfair lock. First claims copy a namespace map and
the changed set: O(namespace count + keys in that namespace), with retries under
competing writers. Repeated unique inserts can therefore be quadratic overall;
high-cardinality delegate/signature keys need profiling before calling this an
optimization. Old immutable packets can remain alive with concurrent readers or
until autorelease pools drain. Unique claims remain process-lifetime until an
explicit namespace reset; there is no cap or eviction policy. Retained-basis
comparison protects concurrent publication, not a lock-free or wait-free claim.

The primary logger still performs formatting, two cached regex passes, private
os_log emission and the opt-in defaults lookup synchronously on its caller.
Only file work is queued. File output retains its `tlinkios.fileLoggingEnabled`
preference, existing paths and fallback, `[TLinkIOS ...]` prefix, UTF-8 output,
1 MiB pre-append rotation threshold and `.1` backup. This threshold is not a
strict maximum file size: one large record can exceed it. Redaction patterns and
`%{private}@` are unchanged. IPv6 and other sensitive values are not newly
redacted; this batch is not a complete privacy assessment.

Primary file records keep a fresh NSDateFormatter so initialization retains the
existing locale/time-zone behavior. DB retains its cached formatter and
synchronous file monitor. A shared formatter is not itself a demonstrated race
on supported iOS: [Apple's DateFormatter documentation](https://developer.apple.com/documentation/foundation/dateformatter?language=objc)
states thread safety on iOS 7 and later. No configuration mutation is introduced
after initialization. Cached versus per-record formatters need behavioral
requirements and profiling before unification.

DB paths, permissions request, per-call path selection, `[DB ...]` prefix and
timestamped blank record for a valid empty format remain. DB is still plaintext,
unbounded and synchronous, so main-thread callers can incur **moderate/high**
storage latency and monitor contention. The primary serial queue still has no
backpressure: an opt-in burst can retain many messages and raise memory/latency.
Rotation/create/append are best effort and are not coordinated across injected
processes; filesystem replacement races, silent failures, partial writes and
durability are not solved. No extra polling, notifications or persistent handle
is introduced. No timing or CPU reduction is claimed.

## Compatibility and scope protection

The app and tweak already compile these common files through `common/*.m` in
Makefile for both rootful and RootHide. No new linked source dependency or new
private selector is required. Header comments document detached inputs,
process-lifetime claims and same-thread reentry suppression. Registry foreign
input exceptions still propagate after cleanup; it is not silently changed into
an always-successful logging API.

All hook `.x` files, installation/coordinator, runtime source writers/readers,
constructor/bootstrap code, Makefile and package metadata remain unchanged.
In particular the RootHide iOS 15.8.8/AIDA64 synchronous cold-bootstrap fix and
ElleKit dependency are preserved. Static preservation does not establish actual
injection, sandbox file access or device behavior for this new batch.

## Validation and native acceptance

`scripts/test_logging_boundaries.py` is enrolled in the release source suite and
macOS CI. `PXLogOnceRegistryTests.m` imports the real registry implementation and
checks pair separation, mutable inputs, exact reset, warm reuse, concurrent
winners/reset publication, reentrant validation and selected exceptional input
lifetime. Its faulting string is a real NSString subclass, rather than an
NSObject masquerading as NSString in Foundation internals.

`PXDiagnosticSinkTests.m` includes exact extracted primary/DB implementations.
Controlled defaults, file-manager/handle, scheduling, formatter, regex and
emission entry points provide deterministic faults; real Foundation formatting,
regex, UTF-8 files/rotation and, in the concurrency case, a real serial GCD queue
exercise the sink flow. Production paths are replaced with a unique temporary
root. Private os_log emission is captured by a facade, so this does not validate
the system log's actual transport/privacy presentation.

The native matrix has two fixtures x rootful/RootHide x plain ARC/ARC exception
cleanup, at -O0: **8 compiler commands and 20 binary runs**, including four
isolated-process sink scenarios per build. The scheme defines exercise common
code portability; they do not simulate RootHide injection or relocated paths.
Source guards cover worker admission before message access, variadic cleanup,
short-lock publication, redaction/opt-in, deferred capture cleanup and DB append
preservation. Twenty negative source mutations are rejected.

Windows verification: **73/74 Python suites and 4/4 Node suites**; the remaining
Keychain retirement suite has the existing Git Bash `mkdir /c/Users/ADMIN`
permission failure (4 failures, 1 error, 1 skip). Source hardening, RootHide
build/package gates, fragment/CHECK checks, protected-file/path/prefix comparisons
and diff checks pass. Recipe capture checked the 8 compile/20 run commands only;
**no native compiler, Foundation binary, Logos/Theos build or device test ran
locally**. The full local source suite was rerun after the final worker-admission
and fixture refinements.

macOS CI must compile and run the entire native matrix, then build both actual
package schemes. Device acceptance should exercise file logging OFF/ON, a log
burst, restricted paths, DB history preservation and normal hook behavior on
rootful and RootHide, including iOS 15.8.8/AIDA64. Full source authority,
movement, profiling and release acceptance remain pending; H5S-partial stays.
