from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
controller = (ROOT / "TLinkIOSViewController.m").read_text(encoding="utf-8", errors="replace")
cell_h = (ROOT / "PXDashboardAppPickerCell.h").read_text(encoding="utf-8", errors="replace")
cell_m = (ROOT / "PXDashboardAppPickerCell.m").read_text(encoding="utf-8", errors="replace")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


require('#import "FreezeManager.h"' in controller, "Reset picker must use FreezeManager explicitly")
require('selected:(BOOL)selected frozen:(BOOL)frozen' in cell_h, "cell API must expose frozen independently of selected")
require('? ?? ??ng b?ng' in cell_m, "frozen state must be visible in the Reset picker row")
require('trailingSwipeActionsConfigurationForRowAtIndexPath' in controller, "Reset picker must expose a trailing swipe action")
require('![self.selectionPickerMode isEqualToString:@"reset"]' in controller, "freeze swipe must be restricted to Reset picker mode")
require('[freezeManager freezeApplication:bundleID]' in controller, "Freeze swipe must call FreezeManager")
require('[freezeManager unfreezeApplication:bundleID]' in controller, "Unfreeze swipe must call FreezeManager")
require('@"?ng d?ng s? kh?ng th? m? cho ??n khi b?n b? ??ng b?ng."' in controller, "Freeze must require explicit confirmation")
require('configuration.performsFirstActionWithFullSwipe = NO;' in controller, "Freeze must not trigger by accidental full swipe")

# Selection/Done remains the only owner of selectedResetAppIDs and must not mutate FrozenApps.
done_start = controller.index('- (void)doneDashboardAppPicker')
done_end = controller.index('- (void)syncHookScopeToResetApps', done_start)
done_body = controller[done_start:done_end]
require('self.selectedResetAppIDs = [selected mutableCopy];' in done_body, "Reset picker Done must still commit reset selection")
require('FreezeManager' not in done_body and 'FrozenApps' not in done_body, "Reset selection commit must not change freeze state")

select_start = controller.rindex('- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:')
select_tail = controller[select_start:select_start + 6000]
require('selectionDraftAppIDs' in select_tail, "row tap must still toggle draft Reset selection")
require('freezeApplication:' not in select_tail and 'unfreezeApplication:' not in select_tail, "row tap must never Freeze/Unfreeze")

print('PASS: Reset picker freeze/unfreeze UI is explicit and independent from Reset selection')


