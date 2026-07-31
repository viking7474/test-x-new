#!/usr/bin/env python3
"""Static Phase-8 Clear Data Quick/Full/Deep contracts."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def text(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")

def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)

request_h = text("PXClearRequest.h")
request_m = text("PXClearRequest.m")
cleaner_h = text("AppDataCleaner.h")
cleaner_m = text("AppDataCleaner.m")
resolver_h = text("PXDataContainerResolver.h")
resolver_m = text("PXDataContainerResolver.m")

for symbol in ("PXClearModeQuick", "PXClearModeFull", "PXClearModeDeep"):
    require(symbol in request_h, f"missing mode: {symbol}")
require("mode:(PXClearMode)mode" in request_h, "typed mode initializer missing")
require("deepClean ? PXClearModeDeep : PXClearModeFull" in request_m,
        "compatibility deepClean mapping changed")
require("return _mode == PXClearModeDeep" in request_m,
        "deepClean compatibility getter changed")
require("mode:(PXClearMode)mode" in cleaner_h,
        "mode-aware public clear API missing")

mode_start = cleaner_m.index("- (void)clearDataForBundleID:(NSString *)bundleID\n                        mode:(PXClearMode)mode")
mode_end = cleaner_m.index("#pragma mark - Improved Rootless-Compatible App Data Wiping", mode_start)
mode_body = cleaner_m[mode_start:mode_end]
require("sync();" not in mode_body, "canonical mode-aware clear must not call global sync")
require("VACUUM" not in mode_body, "canonical entry point must not invoke VACUUM")
require("allCookies" not in mode_body, "canonical entry point must not delete global cookies")
require("plannedPassCount == 2" not in cleaner_m, "second Keychain pass remains")
require("plannedPassCount:(systemApplication ? 1u : 2u)" not in cleaner_m,
        "two-pass Keychain plan remains")
require("plannedPassCount:1u" in cleaner_m, "single Keychain plan missing")
require("plan.plannedPassCount != 1 || passResults.count != 1" in cleaner_m,
        "single-pass accounting guard missing")
require("Step 1: Planning and running single Keychain pass" in mode_body,
        "single Keychain execution log missing")

aggregate_start = cleaner_m.index("- (PXClearResult *)_completeDataWipeForMigratedRequest:")
aggregate_end = cleaner_m.index("#pragma mark - Main Public Methods", aggregate_start)
aggregate_body = cleaner_m[aggregate_start:aggregate_end]
require("!PXClearModeIncludesExtendedContainers(request.mode)" in aggregate_body,
        "Quick aggregate branch missing")
for detail in ("Quick mode excludes extension-data containers",
               "Quick mode excludes App Group containers",
               "Quick mode excludes PluginKit containers"):
    require(detail in aggregate_body, f"Quick skip accounting missing: {detail}")

require("strategy=%@ passed=%d" in mode_body, "verification metric missing")
require("@\"component_manifest\"" in mode_body, "manifest verification missing")
require("@\"deep_residual_scan\"" in mode_body, "Deep verification strategy missing")
for step in ("step=kill", "step=keychain", "step=data_aggregate", "step=verification", "total_ms"):
    require(step in mode_body, f"instrumentation missing: {step}")

require("invalidateCachedContainerForIdentifier" in resolver_h,
        "resolver cache invalidation API missing")
require("PXResolverCachedContainerIsValid" in resolver_m,
        "cache-hit revalidation missing")
require("MCMMetadataIdentifier" in resolver_m and "PXResolverImmediateDirectoryIsValid" in resolver_m,
        "cache validation does not bind metadata and physical directory")
require("removeObjectForKey:cacheKey" in resolver_m,
        "invalid cache hit is not evicted")
require("invalidateCachedContainerForIdentifier:bundleID" in mode_body,
        "request-end cache invalidation missing")

app_wipe_start = cleaner_m.index("- (PXClearComponentResult *)_completeAppDataWipeForApplicationDataRequest:")
app_wipe_end = cleaner_m.index('    NSLog(@"[AppDataCleaner] Completed wipe for %@", bundleID);', app_wipe_start)
app_wipe_body = cleaner_m[app_wipe_start:app_wipe_end]
require("request.mode == PXClearModeDeep" in app_wipe_body,
        "Deep-only specialized cleanup guards missing")
require("PXClearModeIncludesExtendedContainers(request.mode)" in app_wipe_body,
        "Quick residual-cleanup exclusion missing")

# CLEAR-01: dry-run + transaction journal (Phase 14)
require("dryRun:(BOOL)dryRun" not in cleaner_h, "CLEAR-01 dry-run must stay off the public 25-selector header")
require("dryRun:(BOOL)dryRun" in cleaner_m, "CLEAR-01 dry-run implementation missing")
require("PXClearWriteJournal(" in cleaner_m, "CLEAR-01 journal writer missing")
require("dry_run_plan" in cleaner_m, "CLEAR-01 dry-run plan journal phase missing")
require("dry_run_commit" in cleaner_m, "CLEAR-01 dry-run commit journal phase missing")
require("no destructive operations" in cleaner_m, "CLEAR-01 dry-run guard log missing")

# 7.4: granular Clear metrics (Phase 14)
for field in ("step=resolve_container", "resolve_container_ms=", "sqlite_ms=",
              "shell_processes=", "paths_scanned=", "timeout_fallback_count=",
              "first_attempt_success_pct="):
    require(field in cleaner_m, f"7.4 metric field missing: {field}")
for counter in ("gPXClearShellProcessCount", "gPXClearPathsScannedCount", "gPXClearSqliteNanos"):
    require(counter in cleaner_m, f"7.4 metric counter missing: {counter}")

# CLEAR-09: dead brand-specific iOS15 clear path removed (Phase 14)
require("clearAppIssuesForIOS15" not in cleaner_m, "CLEAR-09 dead method still present")
for brand in ("lyft", "zimride", "helix"):
    require(brand not in cleaner_m, f"CLEAR-09 residual brand token present: {brand}")

print("Phase 8 Clear Data static contracts: PASS")
