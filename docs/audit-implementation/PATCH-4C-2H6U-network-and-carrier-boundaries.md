# Patch 4C.2H6U — Network, source staging and carrier catalog batch

2026-11-06. Baseline b258427. User confirms H6T builds and asks for more work per
CI iteration. Read complete NetworkManager/CarrierDB implementations and headers,
address/carrier staging helpers, their lifecycle/source contracts and native
fixtures; trace SecurityTab UI save/read calls and ProfileManager network
preparation on the creation worker. This batch implements fourteen related groups
across three common implementation files, rather than stopping at one accessor.

## Findings and implemented changes

No new device incident or benchmark is established. Source-level defects and
potential exceptional/concurrent failures are distinguished below. The native
reproductions are specified in fixtures but still require macOS execution.

| # | Priority / severity | File / function | Problem, fix and reproduction |
| --- | --- | --- | --- |
| 1 | P1 / Medium potential | NetworkManager, getCurrentLocalIPAddress | inet_ntoa exposes libc-owned output storage. Use a caller-owned IPv4 inet_ntop buffer and check conversion. The inspected Apple source uses static storage; exact iOS 15.8.8 binary behavior is unverified. Native scenarios specify 128 concurrent detections with independent lists/buffers. |
| 2 | P1 / High potential | NetworkManager, generateSpoofedLocalIPv6AddressFromCurrent | Unchecked inet_ntop failure let stringWithUTF8String read an uninitialized stack buffer. Initialize the buffer and skip failed conversions, preserving the established fallback when no conversion succeeds. Test all-fail and first-fail/next-valid conversions. |
| 3 | P1 / Medium potential | Both interface enumeration methods | An Objective-C formatting exception bypassed freeifaddrs. Put list ownership in finally; IPv6 still frees before suffix preparation. Throwing formatting and getifaddrs failure with a supplied list test balanced ownership. No C list is cached or shared. |
| 4 | P2 / Low | Both enumeration loops | NSString creation just to compare each interface name was unnecessary. Compare the checked C name directly with en0; only allocate the final address string. NULL address/name and other-interface cases retain their skip policy. Relative avoided cost low; no benchmark. |
| 5 | P2 / Low correctness | generateSpoofedLocalIPAddressFromCurrent | Ten repeated draws could return the original octet despite the method's stated policy. Keep the ten draws/distribution on ordinary paths, then choose an adjacent allowed octet only when they all repeat. A fixed RNG reproducer verifies ten calls, range and changed output. |
| 6 | P1 / Medium | Saved IPv4/IPv6/carrier readers | Non-string plist fields escaped string APIs, and incomplete/malformed carrier fields could reach UI/string selectors. Accept typed IP strings, retain dedicated-file then IDs precedence, and require a complete typed carrier tuple at each fallback source. Numeric legacy carrier codes become strings; empty strings retain legacy read-hit behavior. Controlled and real-source tests seed malformed primary records with valid fallback IDs and verify no generation/ownership on hits. |
| 7 | P1 / Medium | Explicit IP/carrier saves | Caller-owned mutable strings could change during target lookup or optional IPv6 generation, changing the committed request. Freeze input tuples before acquisition/provider callbacks; preserve nil-pair and nil-to-empty carrier policies. Native and real SourceStore cases mutate inputs during selection/provider callbacks and verify all paired/triple files keep the original values. Unsupported explicit roots fail before acquisition. |
| 8 | P1 / Medium potential | Refresh/provider and path boundaries | Malformed optional provider values could receive length/subscript selectors or seed malformed records. Guard and freeze generated strings and carrier fields, preserve provider metadata and candidate-return-on-save-failure. Reject empty/non-string identity values before file reads, preventing the empty-root relative-path case. Valid path/target authority and fallback country remain unchanged. |
| 9 | P1 / Medium | PXRuntimeArtifactWriter address/carrier stages | Direct stage callers also needed fixed identity/scalars before transaction callbacks. Copy address/identity inputs and lazily detach mutable known carrier strings; preserve unrelated carrier metadata. Release partial base/maps/path/parameters on exceptional exits. Direct-stage tests mutate caller input during the first transaction read, verify one fixed namespace/tuple, and assert no ownership acquisition. Partial second/third-write faults cover abandoned dictionary graphs. |
| 10 | P1 / Medium potential | Network acquisition/source callbacks and flow scopes | Inline method-argument block copies and strong locals/parameters could outlive exceptional unwind in plain ARC. Use named strong callback slots and explicit finally cleanup, including transaction block parameters. Invalidate namespace ownership before logging and before dropping captured roots. Borrowed throwing mocks observe weak input/token/owner/transaction/block roots after pool drain. |
| 11 | P1 / High potential | CarrierDB loadIfNeeded / index construction | self.db became non-nil before countries and MCC/MNC index were complete; overlapping builders also replaced nonatomic roots independently. Publish one complete root/country/index/fallback packet under a short monitor only after all construction. First complete catalog wins; losing candidates are discarded outside the monitor. A paused first builder and a second query verify no partial readiness, no monitor held over construction and no stale replacement. |
| 12 | P1 / Medium | CarrierDB indexed rows | Mutable row dictionaries were returned from a shared index, allowing a caller to alter future query results. Construct immutable indexed rows. Country/alias policies and raw code spelling remain, with source guards for immutable construction and native checks for stable alias contents. No reliance on private Foundation class-cluster names. |
| 13 | P1 / Medium | CarrierDB normalization/index/query/region metadata | Arbitrary descriptions and integerValue on malformed MNC could create aliases for zero/numeric prefixes; unsupported lookup roots could crash, and preferredLanguages could contain non-strings. Limit scalar coercion to strings/numbers, guard normalization and only pad complete one-to-three ASCII-digit MNCs. Preserve exact nonnumeric keys, valid padding and default country/name policies. Invalid language members use existing en-US fallback. Tests cover numeric/trimmed aliases, 1bad/abc false hits, malformed selected rows and metadata. |
| 14 | P2 / Low–moderate | CarrierDB queries | Each operation needs retained ready state and stable caller input across cold provider work. Capture normalized query arguments before loading and query one retained catalog. Warm paths do not re-probe files or rebuild indexes. Tests include reentrant construction, 128 concurrent warm queries and file/probe/build counters. Extra cold builds remain possible; no single-flight wait is introduced. |

Apple source evidence for the conversion change: inspected
[inet_ntoa implementation](https://raw.githubusercontent.com/apple-oss-distributions/Libc/main/net/FreeBSD/inet_ntoa.c)
uses a static output array. This supports removing dependence on its storage;
it does not identify the precise binary shipped on the user's device. The
[inet_ntop implementation](https://raw.githubusercontent.com/apple-oss-distributions/Libc/main/net/inet_ntop.c)
returns NULL on failure. The IPv6 finding is the caller's unchecked error path,
not evidence that ordinary valid en0 conversion commonly fails.

## Preserved behavior and scope

The save flow remains fixed-target, nonblocking lifecycle ownership through
provider/preparation/source staging, then release before compatibility logging.
Saved read hits take no lifecycle/source lock. A miss rechecks the same captured
identity after ownership; it cannot redirect into a newer selection. Existing
IPv6 precedence (network before IDs) and the post-provider merge keep a newer
bypass IPv6 value. Namespace proof, pending deletion, source journaling/rollback,
commit-marker success and no-directory-recreation remain in the existing helpers.
No source engine, lifecycle implementation or their admission policy was changed.

Nil address members still mean unchanged; an empty single-IP save is rejected.
No new IP grammar, canonical formatting or prefix policy is introduced. Stored
empty IP strings remain read hits. Carrier name/code strings preserve case,
whitespace and leading zeroes. Explicit APIs require NSString/nil; numeric legacy
codes are supported at reader/CarrierDB boundaries. Generated carriers retain
unrelated metadata; nil/malformed optional providers now stop rather than persist
malformed/empty data as if a usable carrier were supplied. Once a valid candidate
is generated, save failure still does not turn its return into nil/commit ACK.
Normal provider invocation order/count is retained, including forced IPv4's IPv6
provider step. System IPv6 fallback/suffix formatting and RNG bounds are unchanged.

CarrierDB keeps its ordered jailbreak-aware candidate paths, built-in seed,
secure random selector, default country/name, schema acceptance (>=1), successful
fallback/error-output convention and public random-provider dispatch in region
queries. It still does not refresh an already loaded catalog. Exact nonnumeric
MNC keys remain searchable; they no longer manufacture numeric padding aliases.
Rows with unsupported containers cannot seed usable index/selected carrier fields.
No filtering/reweighting of valid carrier lists, sorting-based collision policy or
locale/code grammar tightening is added. Duplicate normalized keys still have the
existing unspecified dictionary traversal tie policy.

The catalog monitor only retains/initializes one pointer. I/O, JSON decode, index
construction, normalization, providers and logging stay outside it. There is no
condition wait, dispatch_sync, polling, queue or timer. A reentrant builder may
publish a complete inner winner; an older outer builder cannot overwrite it.
Cold concurrent callers may duplicate reads/index construction, particularly
while an earlier builder is indexing. This correctness tradeoff avoids waiting on
foreign construction callbacks; it is not a claim of single-flight I/O.

Catalog immutability covers the normal immutable JSON decode and literal fallback
owned by this implementation, plus immutable constructed indexes/rows. Malicious
subclass/private/KVC mutation, concurrent input mutation during copying and foreign
callee/destructor lifetime remain outside the guarantee. This patch cleans named
owned roots/callback copies; it does not promise cleanup of every compiler-created
temporary in arbitrary foreign code. Stage helper APIs still require their stated
prepared-data/transaction preconditions; not every generic malformed payload is
validated as an IP/carrier identity. The shared PXArtifactPath helper gains input
cleanup; WiFi/Battery/Uptime stage bodies are otherwise preserved exactly.

Production caller evidence includes SecurityTab's field saves/generated carrier
UI and saved-value reads, and ProfileManager's network preparation on the creation
worker. No UI controller, its notifications, worker scheduling or private hook was
changed. UI code that ignores save BOOL and emits a notification, per-keystroke
synchronous saves, broader UI feedback/latency, NetworkConnectionTypeHooks caches,
UptimeManager state, external dataset updates and global reader/source/cache
ordering remain separate work. No app/system overhead improvement is inferred
from source-only tests.

## Performance and compatibility

Avoided per-interface temporary strings have low expected relative cost. New
conversion buffers use stack memory; no cached pointer into an interface list is
retained. The fixed RNG failure fallback does not extend the ten-draw loop.
Typed valid saved hits retain their previous I/O count; malformed records can
perform additional bounded fallback reads instead of returning unsafe values.

Input copies generally retain normal immutable NSStrings and detach mutable
inputs. Carrier staging only rebuilds its packet when a known string copy differs,
then uses that same frozen record for all three writes. Expected overhead low to
moderate on this cold write path; frequency and allocation counts are unmeasured.
Additional ARC cleanup regions can increase code size. Warm CarrierDB reads add a
short monitor/retention, while cold state gains a small publication packet and
possibly duplicate builds. No CPU, latency or retained-byte benchmark is claimed.

Shared common code applies to rootful and RootHide. Standard inet APIs replace no
private API. Package/dependencies/Makefile, constructor/hook/install/scope logic,
captured runtime branches and the iOS 15.8.8/AIDA64 bootstrap fix are untouched.
The manifest clarifies network source coverage without treating the read-only
carrier dataset as a source writer or advancing 4C.2H5S-partial. Full Patch 4 and
later stages remain incomplete.

## Verification

- Windows regression: 62/63 Python suites and 4/4 Node suites pass. Remaining
  Keychain retirement errors are the established Git Bash mkdir /c/Users/ADMIN
  permission issue (4 failures, 1 error, 1 skip). Source hardening and RootHide
  static/package metadata/negative controls (6/6) pass; git diff --check passes.
- New Network fixture compiles exact production class methods and the complete
  address/carrier staging region against controlled C interface/file/source
  collaborators. It specifies conversion failure, list cleanup, ten-draw RNG,
  128 parallel detections, typed fallback, input reentry/freeze, direct staging,
  invalid providers and seven exceptional/partial-write ownership cases. Throwing
  mocks borrow parameters and clean their own references.
- New Carrier fixture compiles the entire implementation region unchanged, with
  controlled file/path collaborators and real Foundation JSON parsing/Security
  RNG. It specifies path/fallback/schema behavior, aliases/types/metadata,
  paused/concurrent publication, 128 warm queries, reentry and exceptional weak
  graph cleanup. File transport and RootHide namespace resolution are stand-ins.
- Existing real SourceStore fixture still compiles actual NetworkManager,
  CarrierDB and staging/source/lifecycle implementations and retains prior tests.
  Added scenarios verify frozen IP/provider/target callbacks, three-file carrier
  consistency, typed malformed read fallback and zero-source-effect invalid input.
- Five fragment generators complete. New network method bodies/declarations are
  exact and unique; the complete carrier implementation and stage region are
  exact extractions. CHECK macro arity is validated for all three fixtures.
  Sixteen negative source controls reject missing conversion/resource/freeze/
  ownership/publication/alias/metadata guards and missing concurrency assertions.
- Singleton, carrier seed/RNG, legacy wrappers, default-country method and the
  unrelated stage region are preserved exactly. Real native recipes remain;
  eight new boundary recipes cover rootful/RootHide x plain ARC/ARC exception
  cleanup at -O0 with Foundation/Security. Compiler/binary calls were captured,
  not executed.

Foundation/xcrun/Theos/device execution is unavailable on this Windows host. New
native assertions, package builds and device behavior require macOS CI/device
verification. No H6U native/build/device pass, benchmark, commit, push or deployment
is claimed.

Continuation note: H6V joins this same uncommitted, pending-CI batch after the
user said "tiếp tục". The uptime-stage preservation and UptimeManager follow-up
statements above describe the H6U checkpoint. See
[H6V report](PATCH-4C-2H6V-uptime-boundaries-and-cache.md) for the intentional uptime
changes and combined validation; there is no separate confirmed H6U build pass.

## Native follow-up — stack-literal capture scope (2026-11-06)

User CI compiled and ran the real source fixture three times at 175/175, then
reached the new Network boundary fixture at 43/47 in rootful plain ARC. The four
faults were tx-read, tx-set, second-write and carrier-third-write. Each reported
owner=1 while input/token/transaction/heap callback roots were zero. The ownership
flag was already released. This is an object-lifetime assertion failure after
compilation, not an undefined symbol or evidence of a held lifecycle lease.

The named heap callback slot did not explicitly bound the stack block literal's
capture scope. Clang's [block emission implementation](https://raw.githubusercontent.com/llvm/llvm-project/main/clang/lib/CodeGen/CGBlocks.cpp)
retains strong stack captures and can extend their cleanup to the enclosing
scope. [ARC exception semantics](https://clang.llvm.org/docs/AutomaticReferenceCounting.html#exceptions)
do not guarantee ordinary strong/full-expression cleanup in plain ARC. A stack
capture surviving a throw is consistent with a released heap block and a live
captured owner. This identifies a missing explicit boundary in our code; the
exact Apple-clang retain sequence still requires native execution/IR inspection,
so no claim is made that every production failed source transaction leaks. The
real source engine normally converts body exceptions into error results; these
fixtures deliberately allow collaborators to unwind through the caller.

Each of the four Network source callback literals now initializes its named slot
inside a separate lexical block. That block ends normally before invoking the
source collaborator. The stack capture cleanup can complete there; the heap
callback keeps all required strong captures alive during the synchronous call
and is cleared by the existing finally if the call throws. The target resolver
uses the same boundary before acquisition. Apply the same rule to Uptime's
resolver and source callback in the pending H6V batch (seven sites in total).
No weak/unsafe mutation capture, byref ownership workaround, exception swallowing
or global ARC build-flag change is introduced. Callback bodies, argument values,
source/provider counts, target validation, post-commit adoption and release-before-
logging order are preserved.

Keep every original fault and weak-root assertion. Additionally observe the
mutation's copied identity string with a weak reference; exceptional fixtures
start from a mutable identity so they do not confuse a constant NSString's
permanent lifetime with a leak. Add four single-address faults covering first
read, existing-IPv6 write, generated-IPv6 second-pass read and second-pass partial
write. Assertions retain exception propagation, no mock commit, ownership release
and provider-count policy. Both first/second callback constructions must release
owner, identity, transaction and heap callback roots after the pool drains.
This also detects a path-only capture leak that an owner-only workaround could
otherwise hide. The production fragments stay exact extractions.

The source gates now require each construction scope to close before callback
invocation. Negative controls remove each of the seven individual construction boundaries;
all must be rejected. New guards also retain the single-address test invocation,
second-pass read fault and copied-identity weak-root assertion. Existing rootful/
RootHide x plain ARC/ARC-EH recipes remain at -O0. Rootful is first in the matrix;
its failure stops later configurations and does not establish a rootful-only bug.

Local verification after the follow-up: artifact writer/preparation source gates,
five fragment generators/exact methods/macro checks, seven construction-scope
negative controls, source hardening, RootHide static/package controls (6/6) and
diff checks pass. Full Windows regression remains 62/63 Python and 4/4 Node;
the only failure is the existing Keychain retirement Git Bash permission issue.
Native compiler/binary recipes were captured, not executed. The reported 43/47
failure has not been rerun on this Windows host; macOS CI must confirm the fix.
No package/bootstrap/hook/dependency/Makefile, source engine or lifecycle engine
change, benchmark, commit or deployment is claimed.

## Native follow-up — getter-result identity lifetime (2026-11-06)

The next user CI run again passed the real source writer fixture three times at
175/175. Network boundaries reached 49/57: all eight failing exceptional cases
reported owner=0, transaction=0, blocks=0, input/token=0 and only identity=1.
The seven construction-scope changes therefore address the previously observed
owner retention, but do not establish complete exceptional lifetime cleanup.
The copied-identity oracle exposed a further retained object after the owner was
gone; it must remain in the assertions.

All four Network callbacks passed mutation.identityDirectory directly as a
staging C-call argument. Uptime's callback used the same pattern. The boundary
between the getter expression and a throwing C stage had no named caller-owned
slot. Under [plain ARC exception rules](https://clang.llvm.org/docs/AutomaticReferenceCounting.html#exceptions),
cleanup of full-expression temporaries is not guaranteed. This is a concrete
remaining cleanup boundary consistent with the log; without the runner compiler
and native execution we cannot establish the exact emitted retain instruction or
rule out an additional fixture/runtime retainer merely from the weak observation.

The five callbacks now evaluate the getter into a named strong identity inside
their existing try, then pass that variable to staging and clear it with the
transaction parameter in finally. The getter assignment completes before the
throwing call. It still happens in the callback at the same point (after Uptime's
epoch check), exactly once per callback invocation. Mutation captures stay strong,
construction scopes stay in place, and the C stages/source/lifecycle engines are
unchanged. There is no new path copy/normalization, namespace lookup, write,
provider, notification, exception catch or ARC build flag.

Keep all eight failing assertions and the copied-identity weak probe. Add a
successful owned-save control which observes a copied path distinct from the
caller's mutable string while the capability is live, clears mock file ownership,
and requires owner/path/transaction/callback roots to disappear after pool drain.
Add four direct-stage exceptional controls for read, write, second-write and
carrier-third-write with an explicitly named immutable identity and weak lifetime
probe, without a capability getter or source ownership. These distinguish a
caller-expression gap from an error in the C stages or the lifetime oracle;
their native outcomes are pending, not assumed to pass. Uptime's capability
stand-in also copies through a mutable temporary to create a distinct owned
identity and adds that identity to its existing exceptional weak-root checks;
this catches the fifth getter boundary without relying on a constant string.

Source guards cover all five getter assignments/cleanup blocks, prohibit inline
identity getter stage arguments, and keep both new controls invoked with their
weak assertions. Fourteen negative controls remove the five named assignments,
five explicit releases, two fixture invocations, the direct weak assertion or
copied-identity distinction; each is rejected. Five generators and exact Network/
Uptime method extraction, CHECK macro arity and eight affected rootful/RootHide x
plain ARC/ARC-EH recipe captures pass. Compiler/binary calls were captured, not
executed. Windows regression remains 62/63 Python and 4/4 Node, with the established
Keychain Git Bash permission failure; source hardening, RootHide metadata/static
controls (6/6) and diff checks pass.

Common code applies to both schemes. Rootful remains first in the matrix and
stops later configurations on failure. The user has not supplied a passing native
result for this follow-up. The added retained local has bounded expected low
cost, unmeasured; hooks/bootstrap/package/Makefile/dependencies are unchanged.
No native/build/device pass or full source-consistency completion is claimed.
