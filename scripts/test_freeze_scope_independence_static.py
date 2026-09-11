from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "FreezeManager.m").read_text(encoding="utf-8", errors="replace")

def require(c, m):
    if not c:
        raise SystemExit(f"FAIL: {m}")

freeze_start = source.index("- (void)freezeApplication:")
unfreeze_start = source.index("- (void)unfreezeApplication:", freeze_start)
isf_start = source.index("- (BOOL)isApplicationFrozen:", unfreeze_start)
freeze = source[freeze_start:unfreeze_start]
unfreeze = source[unfreeze_start:isf_start]

require("isApplicationEnabled:" not in freeze, "Freeze must not depend on scope/enabled state")
require("isApplicationEnabled:" not in unfreeze, "Unfreeze must not depend on scope/enabled state")
require("getApplicationInfo:" in freeze, "Freeze must still validate installed app metadata")
require("getApplicationInfo:" not in unfreeze, "Unfreeze must clear stale state without app metadata")
require("self.frozenApps[bundleID] = @YES;" in freeze, "Freeze must set frozen state")
require("[self.frozenApps removeObjectForKey:bundleID];" in unfreeze, "Unfreeze must clear frozen state")
require(freeze.index("self.frozenApps[bundleID] = @YES;") < freeze.index("[self killApplication:bundleID];"), "Freeze must commit state before killing process")
require("[self saveFrozenState];" in freeze and "[self saveFrozenState];" in unfreeze, "Both operations must persist state")
print("PASS: FreezeManager is independent from spoof/reset scope")
