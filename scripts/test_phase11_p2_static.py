#!/usr/bin/env python3
"""Phase 11 P2 backlog cleanup static contracts: CLEAR-07, CLEAR-09, IOS-04, TIME-01, test mocks."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]


def text(path):
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition, message):
    if not condition:
        raise AssertionError(message)


cleaner = text("AppDataCleaner.m")
tweak = text("TLinkIOSTweak/Tweak.x")
time_h = text("common/PXTimeOffset.h")
time_m = text("common/PXTimeOffset.m")
mocks_raw = text("tests/phase11/mocks.json")

# ---- CLEAR-07: process-wide sync() removed from the cleaner ----
require(re.search(r"(?<![A-Za-z_])sync\(\);", cleaner) is None,
        "CLEAR-07: process-wide sync(); must be removed from AppDataCleaner.m")
require("CLEAR-07 (Phase 11)" in cleaner, "CLEAR-07: rationale marker missing")

# ---- CLEAR-09: generic shared-database mutation is fully quarantined ----
start = cleaner.index("- (void)cleanDatabaseFile:")
end = cleaner.index("- (BOOL)directoryExistsAndHasAnyContent:(NSString *)path {", start)
clean_database_body = cleaner[start:end]
require("PXLogQuarantinedLegacyClearSelector(_cmd)" in clean_database_body,
        "CLEAR-09: generic cleanDatabaseFile must remain fail-closed")
for token in ("DELETE FROM", " LIKE ", "VACUUM", "runCommandWithPrivileges", "rm -f", "sqlite3"):
    require(token not in clean_database_body,
            f"CLEAR-09: quarantined cleanDatabaseFile still mutates shared SQL/files: {token}")
for token in ("%lyft%", "%zimride%", "%uber%", "%helix%", "com.lyft.ios", "com.ubercab.UberClient"):
    require(token not in clean_database_body,
            f"CLEAR-09: hard-coded brand token returned to cleanDatabaseFile: {token}")

# ---- IOS-04: uname stays a single Tweak-owned hook ----
require("IOS-04 (Phase 11): canonical uname owner" in tweak, "IOS-04: ownership marker missing")
require(tweak.count("MSHookFunction(unamePtr,") == 1,
        "IOS-04: uname must be hooked exactly once, by the Tweak")
require("sPXUnameHookInstalled" in tweak, "IOS-04: idempotent uname install guard missing")
for other in (
    "TLinkIOSTweak/JailbreakBypassHooks.x",
    "TLinkIOSTweak/DeviceSpecHooks.x",
    "TLinkIOSTweak/IOSVersionHooks.x",
    "TLinkIOSTweak/DeviceModelHooks.x",
):
    require("MSHookFunction(unamePtr" not in text(other),
            f"IOS-04: no other hook module may install a uname hook ({other})")

# ---- TIME-01: opt-in device time offset, default OFF, bounded, fail-closed ----
for symbol in ("PXTimeOffsetEnabledInSettings", "PXResolvedTimeOffsetSeconds",
               "PXApplyTimeOffsetToDate", "PXTimeOffsetMaxAbsoluteSeconds"):
    require(symbol in time_h, f"TIME-01: public API missing from header: {symbol}")
require("TIME-01 (Phase 11)" in time_h, "TIME-01: header rationale marker missing")
require('timeOffsetEnabled' in time_m, "TIME-01: master toggle key missing")
require("Default OFF" in time_m, "TIME-01: default-off intent must be documented in the resolver")
require("return NO;" in time_m, "TIME-01: enabled check must be able to fail closed to NO")
require("return 0.0;" in time_m, "TIME-01: resolver must return a zero offset when disabled/ambiguous")
require("return baseDate;" in time_m, "TIME-01: apply must be identity when disabled")
require("PXTimeOffsetMaxAbsoluteSeconds = 86400.0" in time_m, "TIME-01: bounded safety clamp missing")
require("dateByAddingTimeInterval:offset" in time_m, "TIME-01: offset application missing")

# ---- App-owned test mocks ----
mocks = json.loads(mocks_raw)
require(mocks.get("owner") == "app", "test mocks must declare app ownership")
require(mocks.get("phase") == 11, "test mocks must target phase 11")
require(mocks["securitySettings"]["timeOffsetEnabled"] is False,
        "test mock must keep the time offset toggle OFF by default")
require(mocks["timeOffset"]["maxAbsoluteSeconds"] == 86400,
        "test mock clamp must match the module clamp")
for forbidden in ("PXLockdownResearchSafety", "com.example.fixture", "353918123456786",
                  "weaponx_ctor", "AAA_TestCtor"):
    require(forbidden not in mocks_raw, f"test mock must not smuggle release-forbidden token: {forbidden}")

print("Phase-11 P2 cleanup contracts: PASS")
