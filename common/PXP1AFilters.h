#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// P1-A — Pure, dependency-free helpers shared by the UserDefaults, DeviceModel
// and Pasteboard Logos hooks (TLinkIOSTweak/*.x) so their core decision logic
// can be exercised by a host-runnable test and can never drift from the code
// that actually ships inside the hooks.

#pragma mark - DeviceModel (§3 DeviceModel)

// Map a machine identifier / model string (e.g. "iPhone15,3") to the generic
// Apple product family returned by -[UIDevice model] / -localizedModel.
// -[UIDevice model] must never expose a machine identifier, so unknown prefixes
// and empty spoof values fall back to the original UIDevice value.
NSString * _Nullable PXDeviceModelUIDeviceFamily(NSString * _Nullable spoofedModel,
                                                 NSString * _Nullable original);

#pragma mark - UserDefaults (§3 UserDefaults)

// YES only for keys on the strict UUID allowlist: exact matches (uuid, udid,
// idfa, idfv, device_uuid, vendor-id, ...) or ".uuid" / "-udid" / "_idfa" style
// suffixes. Generic terms like token/tracking/device/identifier are deliberately
// excluded so non-identifier values are never rewritten.
BOOL PXUserDefaultsIsUUIDKey(NSString * _Nullable key);

// YES when the string is shaped like a UUID: the 36-char 8-4-4-4-12 dashed form
// or a 32-char hex string. Anything shorter than 32 chars is rejected.
BOOL PXUserDefaultsLooksLikeUUIDString(NSString * _Nullable str);

#pragma mark - Pasteboard (§3 Pasteboard)

// Build a deterministic custom-pasteboard name from a PasteboardUUID by replacing
// the last dotted component with the UUID's first group. The general pasteboard
// name must never be passed here. Empty inputs return the original name unchanged.
NSString * _Nullable PXPasteboardDeterministicName(NSString * _Nullable originalName,
                                                  NSString * _Nullable uuidString);

// Legacy loose comparison retained for API compatibility. It is insufficient
// for runtime installation: PasteboardHooks validates the complete signature.
// Exact match or same first return-type character; NULL is incompatible.
BOOL PXPasteboardTypeEncodingCompatible(const char * _Nullable existing,
                                        const char * _Nullable expected);

NS_ASSUME_NONNULL_END
