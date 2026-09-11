from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def text(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def require(cond, msg):
    if not cond:
        raise AssertionError(msg)
    print(f"PASS: {msg}")


def body_between(src, start, end):
    i = src.index(start)
    j = src.index(end, i)
    return src[i:j]


pxdebug = text("TLinkIOSTweak/PXFileDebug.h")
trace_body = body_between(
    pxdebug,
    "static inline BOOL PXFileDebugWebKitTraceEnabled(void)",
    "static inline void PXFileDebugWebKitTrace(NSString *component)",
)
require('/tmp/px_debug_webkit' in trace_body and '/tmp/px_debug_all' in trace_body,
        "WebKit trace remains explicit-marker opt-in")
require('NSBundle mainBundle' not in trace_body and 'NSProcessInfo' not in trace_body,
        "WebKit trace enable check performs no process introspection")
require('hasPrefix:@"com.apple.WebKit"' not in trace_body and 'containsString:@"WebKit"' not in trace_body,
        "WebKit process identity no longer auto-enables tracing")

objc_guard = text("TLinkIOSTweak/ObjcClassPairGuard.x")
ctor = body_between(
    objc_guard,
    "static void PXInstallObjcClassPairGuards(void)",
    "void *libobjc = dlopen",
)
require('PXIsWebKitHelperProcess(bundleID, processName)' in ctor,
        "ObjC class-pair guard explicitly excludes WebKit helpers")
require('PXProcessIsAllowedForSpoofing(bundleID, processName, PXScopeOptionNone)' in ctor,
        "ObjC class-pair guard is scope-gated")
require(ctor.index('PXProcessIsAllowedForSpoofing') < len(ctor),
        "ObjC guard scope gate occurs before libobjc resolution")

main = text("TLinkIOSTweak/Tweak.x")
main_ctor = main[main.index("// Constructor\n%ctor {"):]
early_gate = main_ctor.index("if (!currentProcessAllowed)")
identity_observer = main_ctor.index("PXIdentitySnapshotStartObserving();")
setup = main_ctor.index("setupHookingEnvironment();")
defaults_sync = main_ctor.index("[[NSUserDefaults standardUserDefaults] synchronize];")
require(early_gate < identity_observer < setup < defaults_sync,
        "Main ctor rejects unscoped processes before observers/setup/defaults")
require('BOOL isWebKitHelper = PXIsWebKitHelperProcess(currentBundleID, currentProcessName);' in main_ctor[:identity_observer],
        "Main ctor resolves WebKit-helper state before startup side effects")
require('PXScopeOptionAllowSafariAuthStack' in main_ctor[:identity_observer],
        "Main ctor host-scope gate uses Safari/WebKit host policy")

canvas = text("TLinkIOSTweak/CanvasFingerprintHooks.x")
canvas_ctor = canvas[canvas.index("%ctor {"):]
allowed_pos = canvas_ctor.index("BOOL allowed = PXProcessIsAllowedForSpoofing")
trace_pos = canvas_ctor.index('PXFileDebugWebKitTrace(@"Canvas.ctor")')
require(allowed_pos < trace_pos,
        "Canvas WebKit trace occurs only after scope decision")

uuid = text("TLinkIOSTweak/UUIDHooks.x")
uuid_ctor = uuid[uuid.index("%ctor {"):]
uuid_gate = uuid_ctor.index("if (!launchBundleID.length")
uuid_dispatch = uuid_ctor.index("dispatch_after(dispatch_time(DISPATCH_TIME_NOW")
require(uuid_gate < uuid_dispatch and "PXIsWebKitHelperProcess(launchBundleID, launchProcessName)" in uuid_ctor[:uuid_dispatch],
        "UUID hooks reject unscoped WebKit helpers before scheduling main-queue work")

firebase = text("TLinkIOSTweak/FirebasePerfDisableScoped.x")
fb_ctor = firebase[firebase.index("static void PXFirebasePerfDisableCtor(void)"):]
return_pos = fb_ctor.index("if (!PXIsInTLinkIOSScope()) return;")
dispatch_pos = fb_ctor.index("dispatch_async(dispatch_get_main_queue()")
require(return_pos < dispatch_pos,
        "Firebase retry is not enqueued for unscoped processes")


filter_source = text("common/PXInjectionFilter.m")
require("PXInjectionBundleIsSharedWebKitHelper(bundleID)" in filter_source,
        "Monolithic filter strips shared WebKit helpers centrally")
require("PXInjectionPlaceholderBundleID" in filter_source and
        "PXInjectionLegacyPlaceholderBundleID" in filter_source,
        "Filter migration preserves placeholder-only empty state")
view = text("TLinkIOSViewController.m")
require("addObjectsFromArray:PXDefaultWebKitHelperBundleIDs" not in view,
        "App-side filter writer no longer appends WebKit cluster to monolithic tweak")
daemon = text("WeaponXMountDaemon/WeaponXDaemon.m")
require("PXInjectionComputeTweakBundles(bundles)" in daemon,
        "Daemon sanitizes stale monolithic WebKit targets before install")
print("PASS: WebKit unscoped zero-interference static regression")
