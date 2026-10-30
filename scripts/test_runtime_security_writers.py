#!/usr/bin/env python3
"""Transactional security/canvas writers; defaults authority deliberately partial."""
from pathlib import Path
import argparse
import importlib.util
import json
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
read = lambda path: (ROOT / path).read_text(encoding='utf-8')
spec = importlib.util.spec_from_file_location('identifier', ROOT / 'scripts/test_runtime_identifier_writers.py')
identifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(identifier)
METHODS = ['- (BOOL)setCanvasFingerprintProtection:(BOOL)enabled', '- (BOOL)resetCanvasNoiseAndPersist']
DETAIL = '- (BOOL)persistCanvasValues:(NSDictionary<NSString *, id> *)values'
IP_METHODS = ['- (void)saveLastKnownIP:(NSString *)ip', '- (void)saveIPToCache:(NSString *)ip',
              '- (BOOL)setMonitoringEnabledAndPersist:(BOOL)enabled error:(NSError **)error',
              '- (void)stopMonitoring', '- (BOOL)isMonitoring']
IP_UI = '- (void)ipMonitorToggleChanged:(UISwitch *)sender'
REGION_METHODS = ['- (NSDictionary *)targetRegionDefaultsForCountryCode:(NSString *)countryCode',
                  '- (BOOL)persistPinnedTargetRegionFromResponse:(NSDictionary *)json error:(NSError **)error',
                  '- (BOOL)persistTimeZoneName:(NSString *)name forKey:(NSString *)key',
                  '- (void)publishTargetRegionChanged']
TIME_METHODS = ['- (void)publishTimeSpoofSettingsChanged', '- (BOOL)persistLocationTimeZoneName:(NSString *)name']
DISPLAY_METHODS = ['- (void)webCompatIOSRangeToggleChanged:(UISwitch *)sender',
                   '- (void)displayUIScaleSpoofToggleChanged:(UISwitch *)sender']
SCALAR_READERS = ['BOOL PXReadSecurityBool(NSString *key, BOOL defaultValue)',
                  'NSInteger PXReadSecurityInteger(NSString *key, NSInteger defaultValue)']
INDICATOR_METHODS = ['- (void)handlePan:(UIPanGestureRecognizer *)gesture', '- (NSString *)getPositionFilePath',
                     '- (void)savePositionToFile:(CGFloat)x y:(CGFloat)y', '- (CGPoint)restoredPositionWithDefault:(CGPoint)fallback']


def source_contracts():
    store = read('common/PXSecuritySettingsStore.m')
    for signature in SCALAR_READERS:
        reader = identifier.method(store, signature)
        assert '[value isKindOfClass:NSNumber.class]' in reader and '[value isKindOfClass:NSString.class]' in reader
        assert ': defaultValue;' in reader
    assert 'PXPerformStandaloneRuntimeSourceWrite' in store and '[tx dictionaryAtPath:path error:writeError]' in store
    assert 'if (!existing) return NO;' in store and 'NSPropertyListImmutable' in store
    assert store.index('if (!committed) return NO;') < store.index('PXMirrorSecurityUpdates(updates, mirrorSuites);')
    for forbidden in ('flock(', 'open(', 'writeToFile:', 'NSDataWritingAtomic'):
        assert forbidden not in store, forbidden
    assert 'value == UINT32_MAX ? 1 : value + 1' in store
    assert 'if (committed && committedValue) *committedValue = next;' in store
    assert 'respondsToSelector:@selector(unsignedIntValue)' in store
    metric = identifier.method(store, 'BOOL PXRecordClearAttempt(BOOL firstAttemptSuccess, NSUInteger *totalAttempts, NSUInteger *firstAttemptSuccesses, NSError **error)')
    assert 'existing[@"clearAttemptCount"]' in metric and 'existing[@"clearFirstAttemptSuccessCount"]' in metric
    assert 'successes > attempts' in metric and 'attempts == (NSUInteger)NSIntegerMax' in metric
    assert '@[@"com.weaponx.securitySettings"]' in metric
    for signature in ('BOOL PXWriteSecuritySettings(NSDictionary<NSString *, id> *values, NSError **error)',
                      'BOOL PXAdvanceSecurityNonce(NSString *key, uint32_t *committedValue, NSError **error)'):
        assert '}, PXSecuritySuiteNames(), error);' in identifier.method(store, signature)
    assert 'if (committed)' in metric and '*totalAttempts = nextAttempts' in metric and '*firstAttemptSuccesses = nextSuccesses' in metric
    cleaner = read('AppDataCleaner.m')
    assert cleaner.count('PXRecordClearAttempt(') == 1
    assert 'PXRecordClearAttempt(success && pxTimeoutFallbackCount == 0,' in cleaner
    assert 'counter_persistence_failed error=%@' in cleaner and 'counter_persisted=0' in cleaner and 'counter_persisted=1' in cleaner
    metric_log = cleaner[cleaner.index('BOOL pxCountersPersisted = PXRecordClearAttempt('):cleaner.index('if ([operationContext isCancellationRequested])', cleaner.index('BOOL pxCountersPersisted = PXRecordClearAttempt('))]
    assert metric_log.index('if (pxCountersPersisted)') < metric_log.index('first_attempt_success_pct=%.1f')
    assert 'pxMetricStore' not in cleaner
    position = identifier.method(store, 'BOOL PXWriteProfileIndicatorPosition(double x, double y, NSError **error)')
    assert 'PXPerformStandaloneRuntimeSourceWrite' in position and 'atPath:settingsPath' in position and 'atPath:positionPath' in position
    assert position.index('if (!committed) return NO;') < position.index('PXMirrorSecurityUpdates')
    assert '@[@"com.weaponx.securitySettings"]' in position and '@((float)x)' in position and '@"Timestamp"' in position
    indicator = read('common/ProfileIndicatorView.m')
    pan, path, save, restore = [identifier.method(indicator, method) for method in INDICATOR_METHODS]
    assert 'setFloat:' not in pan and 'synchronize' not in pan
    assert pan.index('UIGestureRecognizerStateEnded') < pan.index('savePositionToFile:')
    assert 'DISPATCH_QUEUE_SERIAL' in save and '__weak typeof(self) weakSelf' in save and '@autoreleasepool' in save
    assert save.index('dispatch_async(self.positionPersistenceQueue') < save.index('PXWriteProfileIndicatorPosition')
    assert 'self.positionWriteToken == token' in save and 'self.pendingPosition = CGPointMake(x, y)' in save
    assert 'dispatch_sync' not in save and 'writeToFile:' not in save and 'PXIndicatorDecodePosition' in restore
    assert 'PXProfileIndicatorPositionPath()' in path and 'PXProfileIndicatorPositionPath()' in read('common/PXRuntimeSources.m')
    core = read('common/PXRuntimeSourceStore.m')
    assert 'allowNested:YES' in core and 'allowNested:NO' in core
    assert 'if (!allowNested)' in core and '_activeTransaction.failure = PXSourceError(@"Standalone source write' in core
    assert 'performStandaloneWrite:body error:error' in read('common/PXRuntimeSources.m')
    for signature in METHODS:
        body = identifier.method(read('common/IdentifierManager.m'), signature)
        assert 'writeToFile:' not in body and 'NSUserDefaults' not in body
    toggle = identifier.method(read('common/IdentifierManager.m'), METHODS[0])
    assert 'PXWriteSecuritySettings' in toggle and '@"canvasFingerprintingEnabled"' in toggle and '@"CanvasFingerprint"' in toggle
    nonce = identifier.method(read('common/IdentifierManager.m'), METHODS[1])
    assert 'PXAdvanceSecurityNonce' in nonce
    assert nonce.index('return NO;') < nonce.index('CFNotificationCenterPostNotification')
    detail = identifier.method(read('CanvasDetailViewController.m'), DETAIL)
    assert 'PXWriteSecuritySettings(values, &error)' in detail and 'writeToFile:' not in detail and 'synchronize' not in detail
    assert detail.index('return NO;') < detail.index('PXPostSettingsChangedNotification()')
    monitor = read('common/IPMonitorService.m')
    observed, cache, enabled, stopped, effective = [identifier.method(monitor, signature) for signature in IP_METHODS]
    for body in (observed, cache):
        assert body.count('PXWriteSecuritySettings(') == 1
        assert '@"CachedIP": ip' in body and '@"IPCacheTime": [NSDate date]' in body
    assert '@"lastKnownIP": ip' in observed and '[self saveIPToCache:' not in observed
    assert '@"lastKnownIP"' not in cache
    assert enabled.index('if (!PXWriteSecurityBool(@"ipMonitorEnabled", enabled, error)) return NO;') < enabled.index('[self startMonitoring]')
    assert '[self stopMonitoring]' in enabled
    assert 'setMonitoringEnabledAndPersist:' in read('common/IPMonitorService.h')
    assert 'if (!_isMonitoring && !self.monitoringTimer && !self.monitoringSessions.count && !self.monitoringToken)' in stopped
    assert 'if (!self.isMonitoring)' not in stopped and '[self.monitoringTimer invalidate]' in stopped and 'self.monitoringTimer = nil;' in stopped
    assert 'return active && enabled;' in effective
    assert 'setObject:' not in monitor and 'setBool:' not in monitor and 'synchronize' not in monitor
    alert = identifier.method(monitor, '- (void)showIPChangeAlertWithOldIP:(NSString *)oldIP newIP:(NSString *)newIP')
    assert alert.index('if (![self setMonitoringEnabledAndPersist:NO error:&error])') < alert.index('IP Monitoring Disabled')
    ui = identifier.method(read('SecurityTabViewController.m'), IP_UI)
    assert 'setMonitoringEnabledAndPersist:enabled error:&error' in ui and '[sender setOn:previous animated:YES]' in ui
    assert 'setBool:' not in ui and 'synchronize' not in ui and 'startMonitoring]' not in ui and 'stopMonitoring]' not in ui
    assert ui.index('return;') < ui.index('[self updateSecurityHeroCount]')
    security = read('SecurityTabViewController.m')
    defaults, region, zone, publish = [identifier.method(security, signature) for signature in REGION_METHODS]
    toggle = identifier.method(security, '- (void)targetRegionFollowsIPToggleChanged:(UISwitch *)sender')
    toggle_commit = identifier.method(security, 'static NSDictionary *PXCommitTargetRegionToggle(BOOL enabled)')
    publisher = identifier.method(security, 'static void PXPublishTargetRegionSettings(void)')
    assert region.count('PXWriteSecuritySettings(values, error)') == 1
    for token in ('targetRegionPinnedCountryCode', 'targetRegionPinnedTimeZoneName', 'targetRegionPinnedCarrierISO',
                  'targetRegionPinnedCarrierMCC', 'targetRegionPinnedCarrierMNC', 'targetRegionPinnedCarrierName',
                  'targetRegionPinnedLocaleIdentifier', 'targetRegionPinnedPreferredLanguages', 'targetRegionPinnedLatitude',
                  'targetRegionPinnedLongitude', 'targetRegionPinnedTimestamp', 'targetRegionPinnedSourceIP', 'networkISOCountryCode'):
        assert token in region, token
    assert 'if ([defaults[@"carrierISO"] length])' in region and 'preferredLanguages"] isKindOfClass:NSArray.class' in region
    assert 'if (!PXWriteSecurityBool(@"targetRegionFollowsIPEnabled", enabled, &error))' in toggle_commit
    assert 'performChange:^NSDictionary *' in toggle and 'PXCommitTargetRegionToggle(enabled)' in toggle
    assert toggle_commit.index('return @{ @"success": @NO') < toggle_commit.index('PXPublishTargetRegionSettings();')
    assert publisher.count('CFNotificationCenterPostNotification') == 3 and 'PXPublishTargetRegionSettings();' in publish
    sync = identifier.method(security, '- (NSDictionary *)applyTargetRegionResponse:(NSDictionary *)json')
    assert 'PXWriteSecuritySetting(' not in sync and 'synchronize' not in sync and 'self.securitySettings set' not in sync
    assert sync.index('if (![self persistPinnedTargetRegionFromResponse:json error:&writeError])') < sync.index('[IPStatusCacheManager savePinnedLocation:') < sync.index('[self publishTargetRegionChanged]')
    assert 'return @{ @"success": @NO' in sync[sync.index('persistPinnedTargetRegionFromResponse:'):sync.index('[IPStatusCacheManager savePinnedLocation:')]
    assert 'persistTimeZoneName:timeZoneId forKey:@"timeSpoofLocationTimeZoneName"' in security
    assert 'persistTimeZoneName:timezoneName forKey:@"timeSpoofIPAddressTimeZoneName"' in security
    assert zone.index('return NO;') < zone.index('CFNotificationCenterPostNotification')
    time_ui = read('TimeSpoofDetailViewController.m')
    time_zone = identifier.method(time_ui, TIME_METHODS[1])
    assert 'PXWriteSecuritySetting(@"timeSpoofLocationTimeZoneName", name, &error)' in time_zone
    assert time_zone.index('return NO;') < time_zone.index('[self publishTimeSpoofSettingsChanged]')
    assert '[self persistLocationTimeZoneName:name]' in identifier.method(time_ui, '- (void)resolvePinnedLocationTimeZone')
    assert 'securitySettings' not in time_ui and 'synchronize' not in time_ui
    for body in (region, zone, time_zone):
        assert 'writeToFile:' not in body and 'setObject:' not in body and 'synchronize' not in body
    for signature, key, fallback in zip(DISPLAY_METHODS, ('webCompatIOSRangeEnabled', 'displayUIScaleSpoofEnabled'), ('NO', 'YES')):
        body = identifier.method(security, signature)
        assert f'PXReadSecurityBool(@"{key}", {fallback})' in body
        assert body.count(f'PXWriteSecurityBool(@"{key}", enabled, &error)') == 1
        assert '[sender setOn:previous animated:YES]' in body
        assert body.index('if (!NSThread.isMainThread)') < body.index('PXWriteSecurityBool')
        assert body.index('[sender setOn:previous animated:YES]') < body.index('CFNotificationCenterPostNotification')
        assert body.count('CFNotificationCenterPostNotification') == 1
        assert 'self.securitySettings' not in body and 'synchronize' not in body and 'setBool:' not in body
    web = identifier.method(security, DISPLAY_METHODS[0])
    assert 'PXReadSecurityBool(@"deviceSpoofingEnabled", NO)' in web
    assert web.index('PXWriteSecurityBool') < web.index('currentValueForIdentifier:') < web.index('WarningLabel.hidden')
    fixture = read('tests/PXRuntimeSecurityWriterTests.m')
    assert fixture.index('#define NSUserDefaults PXFixtureDefaults') < fixture.index('#include "../common/PXSecuritySettingsStore.m"')
    for case in ('empty security packet is a no-op without source or compatibility effects',
                 'invalid security keys values and payloads fail before source entry',
                 'security packet freezes caller graph before staging and mirrors same committed values',
                 'security callback reentry cannot deadlock source gate',
                 'mirror exception cannot negate committed source or suppress other suites',
                 'nested security rejection poisons outer staging and emits no mirror',
                 'capture reentry preserves source and compatibility state',
                 'security commit failure restores source bytes token nonce output and suppresses mirrors',
                 'malformed security dictionary is preserved instead of replaced with empty defaults',
                 'concurrent security nonce updates have no duplicates or lost increments',
                 'canvas protection aliases commit together before notification',
                 'failed canvas alias detail and nonce writes preserve all bytes and emit no success callbacks'):
        assert case in fixture, case
    for case in ('region primary security packet commits all pins and network ISO together once',
                 'region packet preserves omitted language source IP and legacy ISO policy',
                 'invalid region payload and defaults fail before source entry',
                 'region and timezone source faults preserve bytes token mirrors and notifications',
                 'region toggle commit returns previous state on failure without publishing success',
                 'region toggle success retains all three notification topics',
                 'timezone adapters notify only after committed source and preserve unrelated values'):
        assert case in fixture, case
    for case in ('observed IP cache and timestamp commit once preserving unrelated security values',
                 'cache-only IP save preserves last known IP and uses one source commit',
                 'failed IP cache packets preserve bytes token mirrors and notifications',
                 'IP monitor stops and invalidates timer after persisted toggle makes effective getter false',
                 'IP monitor cleans a leftover timer even when running flag is false',
                 'failed IP toggle preserves running timer and emits no service success',
                 'IP monitor UI rolls back failed disable without stopping active timer',
                 'IP monitor UI rolls back failed enable without starting service',
                 'IP monitor UI success starts and stops only after committed setting'):
        assert case in fixture, case
    for case in ('failed display policy write restores persisted switch without mirrors or notifications',
                 'failed display policy write leaves warning and version lookup untouched',
                 'failed display toggle preserves missing-key defaults and absence',
                 'display policy success commits once before all mirrors and one settings notification',
                 'display rollback uses stored value rather than inverse sender state',
                 'WebCompat warning preserves strict version threshold and master dependency',
                 'background display action completes on main without synchronous dispatch'):
        assert case in fixture, case
    for case in ('malformed security scalar types preserve supplied defaults without unsafe selectors',
                 'valid security number and string conversions remain unchanged',
                 'rootful live scalar reader rejects malformed on-disk field types'):
        assert case in fixture, case
    for case in ('clear metric pair commits once before mirrors without runtime notifications',
                 'clear metrics preserve canonical-only legacy mirror scope',
                 'first-attempt success increments both counters together',
                 'legacy decimal metric strings are accepted and canonicalized',
                 'metric source failure preserves bytes outputs mirrors and notifications',
                 'malformed metric counters fail without rewriting source or outputs',
                 'embedded NUL metric text cannot truncate into a valid count',
                 'inconsistent metric pair is preserved instead of silently repaired',
                 'exhausted metrics reject increment without integer wrap',
                 'metric recording never replaces corrupt security root with empty defaults',
                 'concurrent cooperating metric writers preserve all increments and paired totals'):
        assert case in fixture, case
    for case in ('indicator file and float preference pair share one commit before canonical mirrors',
                 'indicator partial write fault rolls back both files and suppresses mirrors',
                 'indicator failure preserves original file absence', 'corrupt indicator root is preserved without committing preferences',
                 'invalid indicator geometry fails before source entry', 'indicator restore preserves preferred-file precedence',
                 'malformed indicator fields safely use legacy preferences fallback',
                 'hide show uses latest pending position without waiting for disk',
                 'serial indicator writes preserve latest point and clear only matching pending token',
                 'indicator pan began and changed never persist on hot path',
                 'drag end clamps and animates while persistence worker is blocked',
                 'queued indicator save does not retain UI owner', 'explicit indicator save survives UI owner release'):
        assert case in fixture, case
    manifest = json.loads(read('docs/audit-implementation/runtime-source-writers.json'))
    assert manifest['rollout'] == '4C.2H4Y-partial'
    for name in ('security-store', 'security-direct'):
        assert manifest['writers'][name]['status'] == 'partial'
    assert manifest['writers']['ip-monitor']['status'] == 'enrolled'
    assert manifest['writers']['security-region-timezone']['status'] == 'enrolled'
    assert manifest['writers']['clear-metrics']['status'] == 'enrolled'
    assert manifest['writers']['indicator-position']['status'] == 'enrolled'
    assert 'ip-monitor' in manifest['sources'][4]['writers']
    assert manifest['writers']['preferences-daemon']['status'] == 'external'
    assert manifest['sources'][4]['field'] == 'securitySettings' and manifest['sources'][4]['status'] == 'partial'
    assert 'test_runtime_security_writers.py --native' in read('.github/workflows/build-ios-arm.yml')
    assert 'test_runtime_security_writers.py' in read('scripts/release_hardening.py')
    print('PASS: Security/canvas source contracts (defaults authority and remaining writers partial; native runtime not implied)')


def generate_native_fragments(folder):
    source = read('common/IdentifierManager.m')
    (folder / 'PXCanvasManagerMethods.inc').write_text('\n\n'.join(identifier.method(source, method) for method in METHODS), encoding='utf-8')
    (folder / 'PXCanvasDetailMethod.inc').write_text(identifier.method(read('CanvasDetailViewController.m'), DETAIL), encoding='utf-8')
    (folder / 'PXIPMonitorMethods.inc').write_text('\n\n'.join(identifier.method(read('common/IPMonitorService.m'), signature) for signature in IP_METHODS), encoding='utf-8')
    (folder / 'PXIPMonitorUIMethod.inc').write_text(identifier.method(read('SecurityTabViewController.m'), IP_UI), encoding='utf-8')
    (folder / 'PXRegionSecurityHelpers.inc').write_text('\n\n'.join(identifier.method(read('SecurityTabViewController.m'), signature) for signature in ['static void PXPublishTargetRegionSettings(void)', 'static NSDictionary *PXCommitTargetRegionToggle(BOOL enabled)']), encoding='utf-8')
    (folder / 'PXRegionSecurityMethods.inc').write_text('\n\n'.join(identifier.method(read('SecurityTabViewController.m'), signature) for signature in REGION_METHODS), encoding='utf-8')
    (folder / 'PXTimeZoneSecurityMethods.inc').write_text('\n\n'.join(identifier.method(read('TimeSpoofDetailViewController.m'), signature) for signature in TIME_METHODS), encoding='utf-8')
    (folder / 'PXDisplayPolicyMethods.inc').write_text('\n\n'.join(identifier.method(read('SecurityTabViewController.m'), signature) for signature in DISPLAY_METHODS), encoding='utf-8')
    (folder / 'PXSecurityScalarReaders.inc').write_text('\n\n'.join(identifier.method(read('common/PXSecuritySettingsStore.m'), signature) for signature in SCALAR_READERS), encoding='utf-8')
    indicator = read('common/ProfileIndicatorView.m')
    (folder / 'PXIndicatorPositionDecode.inc').write_text(identifier.method(indicator, 'static BOOL PXIndicatorDecodePosition(id rawX, id rawY, CGPoint *point)'), encoding='utf-8')
    (folder / 'PXIndicatorPositionMethods.inc').write_text('\n\n'.join(identifier.method(indicator, signature) for signature in INDICATOR_METHODS), encoding='utf-8')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-security-writers-') as temp:
        folder = Path(temp)
        generate_native_fragments(folder)
        sources = ['common/PXRuntimeSourceStore.m', 'common/PXRuntimePublisher.m', 'common/VersionCompare.m', 'tests/PXRuntimeSecurityWriterTests.m']
        for scheme, defines in (('rootful', []), ('roothide', ['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])):
            binary = folder / scheme
            subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions',
                            '-DPX_SOURCE_TRANSACTION_TESTING=1', '-Wall', '-Wextra', '-Werror=implicit-function-declaration',
                            '-I', str(ROOT / 'common'), '-I', str(folder), *defines,
                            *[str(ROOT / source) for source in sources], '-framework', 'Foundation', '-framework', 'CoreFoundation', '-framework', 'CoreGraphics',
                            '-o', str(binary)], cwd=ROOT, check=True, timeout=60)
            for _ in range(3):
                subprocess.run([str(binary)], cwd=ROOT, check=True, timeout=90)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    source_contracts()
    if args.native:
        native_tests()
