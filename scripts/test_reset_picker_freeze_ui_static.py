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
require('@" | Frozen"' in cell_m, "frozen state must be visible in the Reset picker row")
require('trailingSwipeActionsConfigurationForRowAtIndexPath' in controller, "Reset picker must expose a trailing swipe action")
main_impl = controller.index('@implementation TLinkIOSViewController')
swipe_pos = controller.index('trailingSwipeActionsConfigurationForRowAtIndexPath')
require(swipe_pos > main_impl, "freeze swipe method must belong to TLinkIOSViewController, not an earlier helper controller")
require('![self.selectionPickerMode isEqualToString:@"reset"]' in controller, "freeze swipe must be restricted to Reset picker mode")
require('[freezeManager freezeApplication:bundleID]' in controller, "Freeze swipe must call FreezeManager")
require('[freezeManager unfreezeApplication:bundleID]' in controller, "Unfreeze swipe must call FreezeManager")
require('@"This app will be blocked from launching until you unfreeze it."' in controller, "Freeze must require explicit confirmation")
require('configuration.performsFirstActionWithFullSwipe = NO;' in controller, "Freeze must not trigger by accidental full swipe")
require('UIResponder *responder = strongTableView;' in controller, "Freeze confirmation must resolve the controller that owns the Reset picker table")
require('[presenter presentViewController:confirm animated:YES completion:nil];' in controller, "Freeze confirmation must be presented from the Reset picker controller")
require('[ResetPicker][Freeze]' in controller, "Freeze and Unfreeze actions must emit deterministic device logs")
require('@"Freeze"' in controller and '@"Unfreeze"' in controller and '@"Cancel"' in controller, "Freeze UI strings must be ASCII English")
require('@"Select Reset Apps"' in controller and '@"Select RRS Apps"' in controller, "picker titles must be English")
require('@"Search apps..."' in controller and '@"%lu selected"' in controller, "picker search/summary strings must be English")

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


