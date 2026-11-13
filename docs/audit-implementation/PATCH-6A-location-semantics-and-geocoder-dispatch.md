# Patch 6A — Location semantics, circular-region scope and geocoder dispatch

Date: 2026-11-13. Baseline `2524bb7`: user confirms Patch 5A build passed. This
batch handles the two location semantic defects from Patch 6 together with their
canonical-read and geocoder lifetime/delegation boundaries. Patch 4 writer
rollout remains H5S-partial; later movement/profiling stages remain pending.

## Findings and changes

| Priority / severity | Source evidence and practical effect | Implementation / relative cost |
| --- | --- | --- |
| P1 / Medium confirmed semantic defect | CLHeading.headingAccuracy returned snapshot.heading, which is an angle rather than measurement uncertainty. App validity/error checks could receive a direction value or lose the native negative sentinel. | Return the native accuracy once, including negative sentinels. There is no independent heading-accuracy model; GPS horizontal accuracy is not substituted. Removes the active snapshot/provider lookup for this getter. Expected per-call saving is low; no benchmark. |
| P1 / High correctness defect | Active CLRegion.containsCoordinate returned YES regardless of the supplied point or radius, even when original containment was false. | For supported circular regions, evaluate the original point against a native temporary CLCircularRegion with the projected center and original radius. Keep original result for invalid/unsupported input or a projection failure. No independent Earth-distance/boundary approximation. Active queries add a temporary region and another native hit test: moderate relative work compared with the old constant YES, required for correctness. |
| P1 / Medium compatibility risk | Geometric hooks were placed on the generic CLRegion base; unknown/beacon subclasses do not necessarily have circular semantics or expose those selectors. | Move center/containment to a separate CLCircularRegion group. Check complete center/radius/contains ABI before initialization. Exact known class only; unknown, inherited, KVO/private variants keep native behavior. Do not add geometry selectors on CLRegion/CLBeaconRegion. Runtime class normalization can therefore decline projection; this is intentional conservative behavior. |
| P1 / Medium canonical-read risk | Existing bypass protected CLLocation coordinate/speed/course, but heading, source information and map coordinate getters could still project while a canonical/native calculation was active. | Honor the same thread-local bypass for heading angles, source-information booleans, MKUserLocation coordinate and circular geometry. Temporary native geometry holds bypass across construction/hit testing and restores it on every exit. Current snapshot gate, attached heading generation and direct NO-advance policy remain. |
| P1 / Medium exception cardinality defect | Both CLGeocoder hooks called original inside a catch that retried original. Original or synchronous client exceptions could send a second request/replay completion; ordinary NSError delivery is a separate normal path. | Prepare projected location/callback inside the defensive catch, then call original exactly once outside it. Provider failure falls back to original payload once. Original/client exceptions propagate; no retry or redispatch. Reverse location preparation and forward logging policy remain. |
| P1 / Medium potential lifetime issue | Forward completion had implicit captured-handler/parameter lifetime during client exception unwind; hook inputs/prepared roots relied on implicit cleanup. | Named heap callbacks, completed inner literal construction scope, named delivery field load and explicit finally cleanup, including callback result/error parameters. Native ownership may extend the callback after the hook returns; no capture of manager/self is introduced. No new queue/timer/polling or network request is added. |
| P1 / Medium defensive lifetime issue | Raw coordinate/speed/course helpers restored bypass but did not explicitly drop retained C parameters when a getter threw under plain ARC. | Move pure association/bypass functions to common/PXLocationProjection.m, add parameter cleanup and the circular helper. Symbol names and association retention policy stay the same. The manager/snapshot/path engine is byte-for-byte unchanged after extracting these helper definitions. No new writer enrollment. |

Apple defines accuracy as heading uncertainty and circular hit testing from a
center/radius: [CLHeading documentation](https://developer.apple.com/documentation/corelocation/clheading),
[CLCircularRegion documentation](https://developer.apple.com/documentation/corelocation/clcircularregion).
These public contracts support the semantic fixes; they do not establish the
private concrete class/IMP layout on the user's device. Existing public APIs
are retained for iOS 15 support rather than migrating to newer-only monitoring APIs.

## Preserved flow and boundaries

- Keep original manager/delegate identities, native callback collections,
  threading, optional selector capabilities, attached snapshot generations and
  movement/jitter/RNG/timer/persistence behavior. No delegate adapter change.
- Geometry is local reporting/hit testing. No new region is registered with
  CLLocationManager, and this does not synthesize hardware region-entry/exit
  notifications. The temporary identifier is internal and never replaces the
  original region object or its identifier.
- Off/out-of-scope keeps native results/payloads. Known circular projection uses
  one current snapshot and original radius; radius/coordinates must be finite
  and valid. Failed projection leaves the previously obtained native result.
  Original receiver containment is called once; the temporary object has its
  own native evaluation. Unknown classes retain their own original methods.
- Bypass is shared with existing raw location helpers, nested and per-thread.
  It stays active during temporary-object cleanup so reentrant native reads do
  not feed projected state back into canonical state.
- Geocoder wrapping retains result/error/collection identity and native delivery
  queue. Forward completion remains a diagnostic wrapper, with the same copied
  client/address captures; no new cancellation/deduplication policy is imposed.
  A native owner releasing completion without delivery frees captures and does
  not cause the tweak to invent a callback.
- Main ctor admission/bootstrap is unchanged. Its only addition is conditional
  initialization of the narrow circular group after the existing location group.
  Admission checks class/method shape, never a temporary pending snapshot.
  RootHide iOS 15.8.8/AIDA64 bootstrap fix, IOSVersion Patch 5A, package metadata,
  dependencies and Makefile remain unchanged; common source wildcard links the
  extracted projection module for app/tweak.

## Verification

New `test_location_projection_semantics.py` extracts the exact snapshot value
class, seven direct hook bodies and two geocoder methods. Geometry fixture links
the real new projection module and real Foundation/CoreLocation, installs the
extracted circle methods on the native class (only in the test process), and
restores originals. It covers accuracy/sentinels, active/off/attached headings,
association replacement races, synthetic wrong ABI/absent class, original base/
beacon surfaces, native center/far/dateline/polar hit tests, multiple radii,
invalid geometry, native exceptions, unknown subclasses, nested/thread-local
bypass and weak raw-helper argument cleanup. Unsupported host ABI/concrete-class
or subclass-normalizing runtimes emit DETAIL and decline those cases explicitly;
that is not evidence the corresponding device projection works.

Geocoder fixture uses controlled original/providers and the exact hook bodies.
Its log stand-in remains a variadic function, preserving address capture and
argument evaluation. It covers active/off/missing/nil/preparation failures,
synchronous/deferred/background delivery, native/client exceptions, one request
per invocation, unchanged result tuples, native callback release without
fabricated delivery, and weak token/address/result/error roots after pool drain.
Throwing mock boundaries have their own named-root cleanup so their unwind
ownership does not impersonate a tweak leak.

Eight new compile/run recipes cover geometry/geocoder x rootful/RootHide-defined
x plain ARC/ARC exception cleanup at -O0. Old delegate runtime tests remain
registered separately. Static direct/parity tests now enforce the narrow circle
surface and the helper's new file location rather than requiring the broad base
hook. Twenty new negative source controls, exact fragments/CHECK arity/recipe
capture and manager/sensor/bootstrap preservation checks run on Windows.

Local regression: 65/66 Python suites, 4/4 Node. Established Keychain retirement
Git Bash mkdir /c/Users/ADMIN permission failure remains (4 failures, 1 error,
1 skip). Source hardening, RootHide static/package and diff gates pass. Windows
has no Foundation/xcrun/Theos execution: new native recipes were captured, not
compiled/executed. No new native/build/device pass or benchmark is claimed.
Scope/manager/native-geocoder providers are controlled facades; real runtime
scope, hardware, geocoding server and Logos preprocessing need macOS CI/device
verification. Real platform deprecation warnings do not establish API absence.

## Remaining scope

Full Patch 4/5 device acceptance and subsequent stages remain partial. GPS
preferences/captured authority, manager internal locks/cache I/O, movement
simulator state/timer lifecycle, remaining hooks and logging performance are
separate. This batch does not make the whole LocationSpoofingManager thread-safe
or claim full CoreLocation/private-subclass compatibility. Device acceptance
should include active/off/scope changes, actual circular runtime class/ABI,
ordinary/beacon/subclass region behavior and geocoder cancel/error/deferred
flows on supported rootful and RootHide devices.
