# Patch 4C.2H6D — WiFi CF output and ownership boundaries

2026-10-31: user confirms H6C build passes and authorizes continued implementation.
This batch covers Copy adapters and the scan dictionary replacement in WiFiHook.x.
Cache/profile reader, H6B source resolver, H6C installer/swizzles and constructor
are unchanged. The coordinator's CNCopyCurrentNetworkInfo pre-provider flow was
also read: it returns this adapter's owned result directly without another
original call or post-processing pass when the provider handles the operation.

## Findings and changes

1. **High / P1, confirmed unsafe output flow — Apple80211 failure.** The hook
   called original, then read/bridged/released *info even when original returned
   failure without writing output. A valid caller may leave an output slot
   uninitialized and inspect it only after success; the hook's scoped synthesis
   turned that failure into a path reading an indeterminate address. Reproduce
   with an original that returns an error without touching its output and a
   poison initial slot value. Scoped calls now initialize the output-only slot
   before original; the original receives the same pointer address. Missing
   original pointers are similarly safe. The scoped synthesis policy still
   permits a valid fake result/status 0 after original failure.

   Admission runs before original for this adapter, so denied/admission-failure
   calls bypass initialization and keep original pointer/status/untouched-error
   behavior exactly. Original is called once when available. A NULL output
   forwards immediately, without runtime capture, scope or WiFi provider work.
   Original exceptions remain outside preparation catch; directly written output
   is still visible to the caller if original raises. Entry admission ordering
   differs from the old post-original scope check intentionally. RootHide's
   lexical view remains the authority for that operation.

2. **Medium potential / P1 — release before publishing output.** Apple80211
   released the old result before assigning the new one. A destructor/reentrant
   observer could see the old pointer while it was being destroyed. Prepare and
   retain the replacement first, reject unavailable replacement, assign *info,
   then release the displaced owned result. Preserve unknown original dictionary
   fields and the existing SSID_STR/SSID/BSSID/SSID_DATA policy. Existing UTF-8
   encoding failure/empty-string policy is not redesigned in this batch.

   Network/interface Copy adapters also separated preparation from ownership
   consumption. PXWiFiReplaceOwnedCopy takes the original/replacement +1 results,
   keeps original when no replacement exists, otherwise releases original and
   returns replacement. Release exceptions propagate, cleaning the unreturned
   replacement rather than returning an original that may already be freed.
   Apple output is already published when old release runs; an exceptional exit
   leaves that new owned output visible. Tests simulate failure after releasing
   the old object. This does not make arbitrary throwing CF finalizers generally
   supported or guarantee recovery when a finalizer fails before consuming its
   ownership. No ordinary system destructor exception is claimed to be observed.

3. **Medium potential / P1 — CF type assumptions.** SupportedInterfaces called
   CFArrayGetCount without checking a non-NULL original's type. Apple80211 bridged
   a non-NULL original directly into dictionary operations. Validate CF type
   before those operations; unexpected valid CF objects pass through unchanged.
   A wrong-type fixture proves the boundary, not a known real-device payload.
   CFGetTypeID still requires a valid CF object: wild pointers, changed private
   C ABI and concurrently modified caller slots cannot be validated this way.
   The dictionary builder additionally checks NSString types before length/UTF-8
   work; no MAC/SSID format or case policy is added.

4. **Low / P2 — unnecessary interface and scan work.** Nonempty interfaces keep
   their original order and now skip bundle/scope checks and replacement work.
   The existing lexical runtime operation still surrounds original/nested hooks;
   this optimization does not move original outside its captured view. Empty or
   missing interfaces preserve scoped en0 synthesis. A preparation failure keeps
   the old owned array intact.

   Scan replacement now validates the fake pair before allocating a mutable
   dictionary, then copies only when SSID/BSSID or a recognized standard differs.
   Equal results retain original identity/mutability. Actual edits still produce
   a mutable copy and never mutate original. This removes an unconditional copy;
   callers must not rely on the tweak always fabricating a mutable dictionary.
   Preserve ax-before-ac-before-n, case sensitivity and unknown-standard fields.

## Contracts and unresolved private ownership

Apple's [Core Foundation ownership policy](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFMemoryMgmt/Concepts/Ownership.html)
distinguishes Create/Copy ownership from Get access. Its
[CFStringCreateCopy documentation](https://developer.apple.com/documentation/corefoundation/cfstringcreatecopy%28_%3A_%3A%29)
confirms an owned result and notes that an immutable input may simply be retained.
Therefore the old comment claiming a retained copy is safe for both Get and Copy
conventions was incorrect. Correct the comment, but preserve this tweak's current
retained return convention for WiFiNetworkGetSSID/GetBSSID. Actual private
ownership/lifetime across supported device versions has not been established.
If consumers expect +0, the current convention can leak ownership; changing it
to a borrowed/autoreleased pointer without proving lifetime can cause another
failure. That potential issue remains pending, not reported as fixed.

The [primary reversed header](https://gist.github.com/davidmurray/5007313) declares
WiFiNetworkGetSSID without enough ownership annotations to settle this question.
The historical [wpa_supplicant adapter source](https://android.googlesource.com/platform/external/wpa_supplicant_6/+/froyo/wpa_supplicant/src/drivers/MobileApple80211.c)
uses the same two-argument Apple80211GetInfoCopy function-pointer shape as this
tweak. This corroborates a historical signature, not modern iOS ABI or ownership.
The scoped adapter explicitly assumes output-only/+1 Copy semantics, as its old
release logic already did; current-device verification is still required.

Only post-original preparation exceptions are converted into pass-through.
Original exceptions propagate. Denied Apple calls do not inspect or alter output;
scoped calls intentionally define a failed untouched output as NULL before trying
synthesis. A failure to prepare/retain returns the original status and still-owned
result; it never releases original first. NULL output does not trigger fallback
generation/file work. No guarantee is added for concurrent use of the same output
address or mutable foreign dictionaries; normal caller/container contracts apply.

The full RootHide/profile reader and cache region, NEHotspotNetwork property
bodies, initializeHooks and ctor/observer tail are compared with HEAD and unchanged.
Private Get bodies are unchanged apart from the ownership comment. H6B resolver,
source enrollment, process/scope policy, bootstrap and package dependencies remain
unchanged. No new queue, timer, polling, notification or hook is installed. Synthetic
NEHotspotNetwork allocation/KVC and completion behavior remain separate work.

## Performance and validation

Extra CF type checks and output initialization have negligible expected cost.
Nonempty interface queries avoid bundle/scope checks; nil Apple output avoids
all spoof work. Scan queries without applicable changes avoid the dictionary
copy. Expected saving is low per query, potentially cumulative at higher app call
rates; no rate or device latency benchmark is claimed. Successful Copy results
still require their owned result and normal field/data preparation. Source
fallback latency and private Get per-call retains remain separate concerns.

The existing artifact-preparation --native recipe adds PXWiFiCFHookTests.m for
rootful and RootHide. It extracts seven exact bodies and five exact original
pointer/type declarations. Controlled CF retain/release/copy collaborators inject
NULL/exception cases; those tests are not a claim that ordinary non-NULL
CFBridgingRetain normally allocates/fails. Real CF objects and destructor probes
check surviving ownership, cleanup and merged-descendant lifetime. A release
observer verifies publication order before consuming old ownership.

Cases cover original-once forwarding, missing function pointers, malformed input,
scope/provider/retain/copy failure, original/release exceptions, caller poison,
NULL/denied output, scoped synthesis after original failure, valid unexpected CF
types, interface order, UTF-8/alias fields, scan copy/no-copy and standard priority.
The host fixture does not execute MobileWiFi/private frameworks or a hook backend.

Local Windows: 62/63 Python and 4/4 Node gates pass; the remaining failure is the
known bridge-retirement Git Bash mkdir permission issue. Source hardening,
RootHide metadata/static gates, four native fragment generators, seven exact CF
bodies/dependency order, CHECK/duplicate-class checks and 14 in-memory ownership,
output, generation and fixture negative controls pass. Final regression/targeted
checks are rerun after lexical-scope review. Foundation/Theos/package/device
execution is unavailable locally; H6D requires macOS CI/device verification.
Full Patch 4 and private ownership/compatibility coverage remain partial.
