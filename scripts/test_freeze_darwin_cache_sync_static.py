from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
manager = (ROOT / "FreezeManager.m").read_text(encoding="utf-8", errors="replace")
hook = (ROOT / "TLinkIOSTweak" / "SpringBoardLaunchHook.x").read_text(encoding="utf-8", errors="replace")

def require(c, m):
    if not c:
        raise SystemExit(f"FAIL: {m}")

name = 'com.hydra.tlinkios.freezer.changed'
require(name in manager and name in hook, "writer and SpringBoard reader must use the same Darwin notification")
require('CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter()' in manager, "FreezeManager must publish cross-process changes")
require('CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter()' in hook, "SpringBoard must observe cross-process freeze changes")
require('PXFreezePreferencesChanged' in hook, "SpringBoard must invalidate its freeze cache")
require('cacheLastUpdated = [NSDate distantPast];' in hook, "freeze cache invalidation must force immediate reload")
init = hook.index('dispatch_once(&onceToken')
window = hook[init:init + 500]
require('cacheLastUpdated = [NSDate distantPast];' in window, "first SpringBoard query must load persisted FrozenApps immediately")
print("PASS: Freeze state changes invalidate SpringBoard cache cross-process")
