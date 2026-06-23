#import <Foundation/Foundation.h>

// Darwin notification constants
#define PX_NOTIFICATION_CONFIG_CHANGED CFSTR("com.hydra.projectx.config.changed")
#define PX_NOTIFICATION_SCOPE_CHANGED CFSTR("com.hydra.projectx.scope.changed")

// Centralized scope helpers for ProjectXTweak.
// Goal: keep spoofing decisions consistent across modules, especially for Safari/Auth stack.

BOOL PXDeviceSpoofingEnabled(void);
BOOL PXSafariStackSpoofEnabled(void);

// Test mode: forces spoofing in Safari/Auth stack for failure testing.
BOOL PXFullSpoofTestModeEnabled(void);

// Display spoof controls (native + web). These are intended for test builds.
// - UIScale affects UI sizing/zoom (bounds/scale/nativeScale).
// - PixelMetrics affects fingerprint-visible pixel size (nativeBounds, etc.).
// - WebScreen affects JS-visible metrics (screen.width, devicePixelRatio, etc.).
BOOL PXDisplayUIScaleSpoofEnabled(void);
BOOL PXDisplayPixelMetricsSpoofEnabled(void);
BOOL PXDisplayWebScreenSpoofEnabled(void);

BOOL PXIsSafariStackProcess(NSString *bundleID, NSString *processName);
BOOL PXAllowUnscopedSafariStack(void);
