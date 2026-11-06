# Patch 4C.2H6J — WiFi custom-input snapshot and admission

2026-11-06: user confirms H6I build passes and authorizes continued implementation.
Read WiFiManager in full, its header, identity validator, paired artifact staging,
lifecycle acquisition, current caller inventory and the preparation/cache fixtures.
This batch changes only setCurrentWiFiInfo: plus its API comment and regression
coverage. All other WiFiManager method bodies reconstruct HEAD unchanged.

## Findings and changes

1. **Medium potential / P1 — validated input differs from the stored candidate.**
   common/WiFiManager.m, setCurrentWiFiInfo: (line 369). The setter read the external
   dictionary repeatedly, validated its fields, then made a shallow mutableCopy.
   A custom dictionary could return different values to validation and copy. More
   normally, NSMutableString SSID/BSSID values survived that shallow copy, so a
   subsequent provider callback/caller mutation could change cache and paired
   WiFi/device-ID output after validation.

   Copy the root first, read required fields once from that candidate, and copy
   NSString fields before validating the same copied values. Bind those values
   back into the candidate before publication. Preserve spelling, whitespace,
   separator/case and the existing PXValidateIdentityValue grammar; this is not
   canonicalization. Unknown metadata still follows the shallow-copy policy.
   Reproduce with mutable fields changed by the optional manager warmup callback,
   or a controlled input whose copied root has an invalid SSID despite valid
   earlier subscript results. The fixture checks cache plus both persisted files.

2. **Medium potential / P1 — old preparation can become a new cache owner.**
   Same function, admission after input validation. A concurrent adoption/reload,
   or reentrant input accessor, could publish newer B before the old setter
   called beginWiFiCacheUpdate. The old operation would then obtain a fresh
   revision and overwrite B. Observe revision before the first foreign input
   method; prepare outside the monitor/lease, then conditionally claim that
   revision. Superseded preparation exits without target lookup, source writes
   or cache invalidation. The deterministic input type-check callback adopts B
   while a valid older A is being prepared; B remains readable and no writer or
   provider is entered. No device occurrence/frequency is established.

3. **Medium potential / P1 — stale validation can overwrite a newer lastError.**
   Same function, direct self.error assignment/public validator calls. Validation
   performed outside the cache protocol could write its result after a newer
   operation completed. Use the existing pure identity validator in the setter,
   prepare the same domain/code/message locally, and publish errors only if the
   observed revision still matches. Missing fields retain priority over invalid
   SSID; invalid SSID still precedes BSSID validation. Standalone public validation
   methods remain unchanged. The invalid-input callback fixture adopts newer B
   and verifies that its nil error is not replaced by the old validation failure.

These are public-API boundary fixes. The repository has no production call to
setCurrentWiFiInfo: and no production override of isValidSSID:/isValidBSSID:
outside the manager implementation; tests are the current direct callers. Do not
infer that these paths caused the earlier AIDA64 issue or a measured hot-path
regression. The repeated reads, retained mutable field aliases and ordering gaps
are present in source; actual invocation on a device is not established here.

## Compatibility and lifecycle limits

For ordinary Foundation inputs, nil remains a complete no-op. Invalid root or
missing fields retain com.hydra.tlinkios / 3001; invalid SSID and BSSID retain the
identity-validator domain / 3003 and 3005 with their existing messages. Invalid
input does not change revision/readability/data or start persistence. A bad copy
result from a custom mutableCopy implementation is rejected as 3001. Copying now
occurs before validation; a foreign copy that throws can therefore propagate
before a validation error. No blanket exception suppression is introduced.

Valid input still publishes a cache-first, initially unreadable candidate, then
uses the existing owned current-target paired save. Persistence failure retains
that candidate/error policy. Manager-first target authority, default/numeric file
fallback, source staging/rollback, commit receipt and post-commit adoption are
unchanged. The setter now calls the unified pure validator directly rather than
dispatching public stateful validator methods; no in-repository override depends
on the old dispatch, but third-party overrides/swizzles are not covered.

Invalid or throwing preparation no longer invalidates a readable cache. All owned
references are cleared in finally, including exception exits, without holding the
cache monitor/lifecycle lease around input copy or validation. Supersession after
preparation is checked again by the existing publication/save revision helpers;
a source write already in flight is not undone merely because cache state changes.

This does not synchronize concurrent mutation of the caller's dictionary during
copy, defeat hostile NSString copy implementations, deep-freeze optional metadata,
or provide a global selection/source generation. Public standalone validators,
other instances and external writers remain outside this revision protocol. No
extra observer, queue, retry, timer, file probe or writer enrollment is added.
RootHide bootstrap/scope/hooks/package dependencies and H6A-H6I remain untouched.
The shared common source is included in both package schemes. Full Patch 4 and
rollout marker H5S-partial remain partial.

## Patch outline

```objc
@synchronized (self) { revision = _wifiCacheRevision; }
candidate = [wifiInfo mutableCopy];
ssid = [rawSSID copy]; // after the field type check
// Validate copied fields and bind them to candidate; preserve original spelling.
if (failure) { [self setWiFiCacheError:failure revision:revision]; return; }
revision = [self beginWiFiCacheUpdateIfRevision:revision];
if (!revision) return;
// Existing conditional candidate publication and owned paired save follow.
```

## Performance and verification

Expected overhead is low on this explicit setter: one added short observation
monitor, conditional rather than unconditional admission, and at most two string
copies. Foundation immutable string copies normally share their immutable object;
mutable fields require detached storage. The root is still copied once, now before
validation, so rejected dictionary inputs can allocate a copy that the old code
avoided. Superseded work skips provider/lease/write work. No measured CPU, I/O,
latency, memory reduction or contention result is claimed; hook hot paths do not
call this setter in the current repository.

The existing owned artifact fixture adds a nine-case input/error matrix, nil,
copied-root disagreement, copy exception, mutable root/required-field change at
provider warmup, and valid/invalid preparation supersession cases. It verifies
cache eligibility, no unintended provider/candidate-copy/source effects, exact
paired file values and released lifecycle ownership, then restores the baseline
record. Native input collaborators clear their own callback references.

Local Windows validation:

- 62/63 Python and 4/4 Node regression suites passed. The remaining suite is the
  known test_keychain_bridge_retirement.py Git Bash mkdir /c/Users/ADMIN permission
  failure (4 failures, 1 error, 1 skip), unchanged from H6I.
- Artifact source contracts, Phase-10 source hardening, RootHide build static and
  RootHide metadata/negative controls (6/6) passed.
- Four affected native fragment generators completed; every owned WiFi method,
  including the new setter, is extracted exactly once. No new header dependency,
  selector declaration or link source is needed by the native fixture.
- Ten in-memory source negative controls reject raw input rereads, SSID/BSSID
  aliases, either skipped validator, unconditional admission, stale direct error,
  missing frozen-field binding, missing mutable-copy result guard and missing
  owned-reference cleanup. These are source-gate checks, not native execution.
- Captured recipe inspection confirms the owned source fixture still compiles
  for rootful and RootHide with Foundation/CoreFoundation and the existing ARC /
  Objective-C exception flags. Compiler/binary calls were captured, not executed;
  the existing ARC-exception matrix for separate cache fixtures is unchanged.
- Exact preservation outside the single setter body and git diff --check passed.

Foundation/xcrun/Theos and iOS device execution are unavailable on this Windows
host. Native assertions, both package builds and device behavior require macOS
CI/device verification. No new native/build/device pass, commit, push or deployment
is claimed.
