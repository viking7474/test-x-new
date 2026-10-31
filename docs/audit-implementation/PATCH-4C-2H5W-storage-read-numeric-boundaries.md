# Patch 4C.2H5W — Storage read, model and numeric boundaries

2026-10-30: user confirms H5V build passes and authorizes continuation. This batch
changes shared StorageManager read/default code and the active block-count helper
in StorageHooks.x. Source-writer enrollment remains H5S-partial. It does not
change H5V commit semantics, bootstrap, process classification or hook installation.

## Findings and changes

1. **Medium / P1, confirmed unsafe numeric conversion:**
   convertGBStringToBytes: sent doubleValue to arbitrary non-nil objects and cast
   the product directly to uint64_t. Arrays/dates can raise a selector exception;
   NaN/infinity or values outside the unsigned range make the C conversion
   undefined. Admit NSString/NSNumber and reject nonpositive/non-finite inputs or
   products at/above the exclusive 2^64 limit before casting. Return 0 for those
   invalid values, retaining the existing missing/invalid value convention.
   NSNumber support preserves old doubleValue-capable numeric plist values.

2. **Medium / P1, potential boundary overflow:**
   normalizeStorageBytes: accepted an already valid uint64_t, rounded in double
   and converted without checking whether the rounded result still fit. Near
   UINT64_MAX it can exceed the unsigned domain. Preserve the original input
   byte count when rounding cannot fit. Keep every ordinary threshold, rounding
   rule, marketing unit and compatibility switch behavior. The exclusive limit
   is 0x1p64; an inclusive double comparison against UINT64_MAX would itself be
   rounded to 2^64. Extreme capacities are not claimed to occur on real devices.

3. **Medium / P1, confirmed return/selector risk:**
   totalStorageCapacity/freeStorageSpace/filesystemType returned raw cached plist
   members through NSString APIs. Scalar getters now share a root/field guard:
   strings remain strings, numbers use stringValue, unsupported types return nil.
   They do not rewrite cached/source values. A malformed numeric previous capacity
   no longer receives length during repeat avoidance. The entire cache/load API
   is not promoted to a schema validator: a dictionary load can still return YES
   even when some of its stored fields are unusable through scalar getters.

4. **Medium / P1, confirmed wrong-profile fallback:**
   loadFromProfile:A on a missing storage file called setDefaultStorage, which
   selected hardware through PXActiveProfileID. If B was active, the A load could
   fabricate defaults from B's model. Add targeted capacity/default helpers and
   keep the validated requested ID through the model file read and preparation.
   No-argument legacy wrappers retain active-profile/legacy-selection authority.
   Defaults remain ephemeral and do not create storage files/directories or
   acquire a writer lease. Failed generation still clears the three owned cache
   fields while preserving unrelated cache fields, avoiding stale prior-profile
   capacity display.

5. **Medium / P1, confirmed malformed model path:**
   randomizeStorageCapacityForDeviceModel: passed an untyped model into
   IPhoneModelDB, whose specForProductType: sends length. Reject unsupported model
   types before the DB factory; guard optional row/spec dictionary roots before
   subscripting. Explicit invalid profile IDs reject before path/default/cache
   work; the current-profile loader treats malformed canonical IDs as absent.
   Nil/empty model generic tiers, canonical-only unknown-iPhone policy, supported
   tier order, duplicate tier behavior and legacy integerValue tier parsing stay
   unchanged. Current-loader defaults still use the legacy active hardware
   fallback when canonical selection is absent/invalid, as before.

6. **Low / P2, active arithmetic edge case:**
   StorageHooks.x calculateBlockCount used (bytes + blockSize - 1) / blockSize.
   Unsigned addition wraps near UINT64_MAX and can report zero/wrong block counts.
   Use quotient plus a nonzero-remainder indicator. It is valid across the entire
   input domain; zero block size still uses DEFAULT_BLOCK_SIZE. This helper is
   used by the existing statfs fields. Ordinary hardware-sized inputs are
   unchanged; reachability of extreme inputs on a device is not asserted.

7. **Low / P2, allocation and maintenance cleanup:**
   The capacity chooser now copies its local array only when filtering a previous
   value can be needed; it retains the original list for duplicate-only fallback.
   Remove two static, explicitly unused GB conversion/normalization functions
   from StorageHooks.x after checking that their names appeared only at their
   definitions in that file. They duplicated the unsafe code and had no active
   callers. Removing dead helpers has no claimed runtime speedup.

## Reproduction and validation

Use temporary files or controlled adapters: load a missing A storage file while
B is active and give A/B distinct single-tier model specs; use arrays as model or
numeric fields; invoke conversions with NSNumber NaN/infinity or values at 2^64
after scaling; normalize UINT64_MAX; compute block count at UINT64_MAX with 4096.
These demonstrate code-level failure paths/boundaries rather than a device crash
frequency. Correctness fixes precede the low-cost allocation cleanup.

Extend the existing artifact preparation recipe for rootful and RootHide. It now
extracts twenty additional exact StorageManager read/default methods and their
declarations, the scalar C helper, the active hook block-count C helper and the
exact production unit/default-block constants. Controlled IPhoneModelDB and
DeviceModelManager adapters isolate type/model/tier behavior without UIKit or
the device database service. The active-ID adapter implements the relevant
canonical/legacy selection behavior in temporary files.

Native cases cover scalar coercion without cache rewrite, malformed types,
non-finite/overflow conversion, fractions/prefix parsing, marketing-only legacy
switches, normal normalization tiers, uint64 limits, and a 128-bit independent
block coverage oracle across zero/default/one/max block sizes. The profile/model
matrix covers inactive target hardware, ephemeral defaults, invalid input before
lookup, numeric previous capacity, single/duplicate tiers, malformed canonical
specs, unknown-iPhone rejection and generation failure field clearing. It restores
exact original file bytes/absence and the random fixture tape in finally, then
checks all source bytes/marker and write/notification counters to prevent test
pollution. The H5V commit API and legacy persistence bodies are compared with HEAD
and remain unchanged.

Local Windows: 62/63 Python and 4/4 Node gates pass, plus source hardening,
RootHide metadata/static contracts, exact identifier/artifact/group/profile
fragments, CHECK arity and 12 in-memory negative controls. The single Python gate
failure remains the known bridge-retirement Git Bash mkdir permission issue.
Native Foundation/Theos/device execution is unavailable locally; the expanded
native cases and actual package builds require the next macOS CI run.

## Performance and remaining boundaries

Scalar/numeric guards are low relative CPU cost, with no I/O, IPC, allocation for
already-string getters, locks or queues. Legacy NSNumber-to-string coercion
allocates when required by the API. The block calculation adds a remainder to
division; expected overhead is negligible, with no benchmark claim. Lazy copying
saves one array copy only when repeat filtering is unnecessary; this is a small
allocation reduction, not a claimed hot-path bottleneck fix.

Explicit invalid inputs avoid model/path/default work. Valid missing-profile
defaults read the requested model file instead of the active model file; no
polling, callback or network mechanism is added. Defaults/loads still read files
synchronously without a coherent multi-file source snapshot. Cache getters,
in-place load/default mutation and legacy setters remain globally unsynchronized;
there is no new thread-safety, cross-process ordering or purity guarantee.
Provider exceptions inside hostile Foundation subclasses are not broadly caught.
RootHide's IdentifierManager injected snapshot prefix, cold-bootstrap fix and
packaging dependencies are untouched. Full Patch 4 remains partial.
