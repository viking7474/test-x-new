from pathlib import Path

p = Path('AppDataCleaner.m')
s = p.read_text(encoding='utf-8')

def replace_method(signature: str, body_lines: list[str]) -> None:
    global s
    start = s.index(signature)
    brace = s.index('{', start)
    depth = 0
    i = brace
    in_str = False
    esc = False
    while i < len(s):
        ch = s[i]
        if in_str:
            if esc:
                esc = False
            elif ch == '\\':
                esc = True
            elif ch == '"':
                in_str = False
        else:
            if ch == '"':
                in_str = True
            elif ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
                if depth == 0:
                    end = i + 1
                    new_body = signature + '{\n' + '\n'.join(body_lines) + '\n}'
                    s = s[:start] + new_body + s[end:]
                    return
        i += 1
    raise RuntimeError(f'unclosed method: {signature}')

replace_method('- (void)cleanRootHideVarData:(NSString *)bundleID ', [
    '    (void)bundleID;',
    '    // RootHide compatibility cleanup historically used bundle-prefix wildcards across',
    '    // shared mobile/root preferences, caches, WebKit, cookies and temporary directories.',
    '    PXLogQuarantinedLegacyClearSelector(_cmd);',
])

replace_method('- (void)clearThumbnailCaches:(NSString *)bundleID ', [
    '    (void)bundleID;',
    '    // ThumbnailServices/QuickLook caches are shared system stores; filename prefixes do',
    '    // not prove ownership by the selected application.',
    '    PXLogQuarantinedLegacyClearSelector(_cmd);',
])

replace_method('- (void)clearSystemLogs:(NSString *)bundleID ', [
    '    (void)bundleID;',
    '    // CrashReporter/DiagnosticReports/ASL/system logs are shared diagnostic stores and',
    '    // bundle-name wildcard matching is not an ownership boundary.',
    '    PXLogQuarantinedLegacyClearSelector(_cmd);',
])

replace_method('- (void)clearMediaData:(NSString *)bundleID ', [
    '    (void)bundleID;',
    '    // Camera Roll, Downloads, Messages attachments and Photos databases are shared user',
    '    // media. App-name/bundle substring matching cannot authorize destructive deletion.',
    '    PXLogQuarantinedLegacyClearSelector(_cmd);',
])

replace_method('- (void)clearHealthData:(NSString *)bundleID ', [
    '    (void)bundleID;',
    '    // Health/HealthKit are shared protected stores. A filename containing a bundle id',
    '    // is not proof that the target application owns the health record or database row.',
    '    PXLogQuarantinedLegacyClearSelector(_cmd);',
])

replace_method('- (void)clearSafariData:(NSString *)bundleID ', [
    '    (void)bundleID;',
    '    // Shared Safari history/bookmark/tab databases must not be edited by fuzzy URL/title',
    '    // matching. Explicit MobileSafari shared-web cleanup is separately policy-gated.',
    '    PXLogQuarantinedLegacyClearSelector(_cmd);',
])

replace_method('- (void)clearClipboard ', [
    '    // The general pasteboard is device-wide shared state and has no target bundle owner.',
    '    PXLogQuarantinedLegacyClearSelector(_cmd);',
])

p.write_text(s, encoding='utf-8')
print('quarantined legacy global/shared clear helpers')
