#import <Foundation/Foundation.h>
#include <fcntl.h>
#include <mach-o/dyld.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

static inline BOOL PXFileDebugContainsNoCase(const char *haystack, const char *needle) {
    if (!haystack || !needle || !needle[0]) return NO;
    size_t needleLen = strlen(needle);
    for (const char *p = haystack; *p; p++) {
        size_t i = 0;
        while (i < needleLen && p[i]) {
            char a = p[i];
            char b = needle[i];
            if (a >= 'A' && a <= 'Z') a = (char)(a - 'A' + 'a');
            if (b >= 'A' && b <= 'Z') b = (char)(b - 'A' + 'a');
            if (a != b) break;
            i++;
        }
        if (i == needleLen) return YES;
    }
    return NO;
}

static inline void PXFileDebugWritePath(const char *path, const char *line, size_t len) {
    if (!path || !line || !len) return;
    int fd = open(path, O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd < 0) return;
    write(fd, line, len);
    close(fd);
}

/// AIDA64 file-debug is OPT-IN only. Auto-enabling for any "aida" process caused
/// massive open/write on every hook/ctor and made AIDA64 hang / apps launch slowly.
/// Enable with: touch /tmp/px_debug_aida64  OR  touch /tmp/px_debug_all
static inline BOOL PXFileDebugAIDA64Enabled(void) {
    static int enabled = -1;
    if (enabled != -1) return enabled == 1;
    enabled = 0;
    if (access("/tmp/px_debug_all", F_OK) == 0 || access("/tmp/px_debug_aida64", F_OK) == 0) {
        enabled = 1;
    }
    return enabled == 1;
}

static inline BOOL PXFileDebugWebKitTraceEnabled(void) {
    if (access("/tmp/px_debug_all", F_OK) == 0 || access("/tmp/px_debug_webkit", F_OK) == 0) return YES;
    @autoreleasepool {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        NSString *processName = [NSProcessInfo processInfo].processName;
        if ([bundleID isEqualToString:@"com.apple.SafariViewService"] ||
            [bundleID hasPrefix:@"com.apple.WebKit"] ||
            [processName containsString:@"SafariViewService"] ||
            [processName containsString:@"WebContent"] ||
            [processName containsString:@"Networking"] ||
            [processName containsString:@"GPU"] ||
            [processName containsString:@"WebKit"]) {
            return YES;
        }
    }
    return NO;
}

static inline void PXFileDebugWebKitTrace(NSString *component) {
    if (!PXFileDebugWebKitTraceEnabled()) return;
    @autoreleasepool {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
        NSString *processName = [NSProcessInfo processInfo].processName ?: @"";
        NSString *exe = [[NSBundle mainBundle] executablePath] ?: @"";
        NSString *home = NSHomeDirectory() ?: @"";
        NSArray *args = [NSProcessInfo processInfo].arguments ?: @[];
        NSDictionary *env = [NSProcessInfo processInfo].environment ?: @{};
        NSArray *interestingEnvKeys = @[
            @"XPC_SERVICE_NAME",
            @"APP_SANDBOX_CONTAINER_ID",
            @"HOME",
            @"TMPDIR",
            @"CFFIXED_USER_HOME",
            @"__CF_USER_TEXT_ENCODING",
            @"_LSServer_ClientBundleIdentifier",
            @"LSBundleIdentifier",
            @"NSBundleMainBundleIdentifier"
        ];
        NSMutableDictionary *envOut = [NSMutableDictionary dictionary];
        for (NSString *key in interestingEnvKeys) {
            NSString *value = env[key];
            if ([value isKindOfClass:[NSString class]] && value.length) envOut[key] = value;
        }

        NSDictionary *metadata = nil;
        NSString *metadataPath = [home stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
        if (metadataPath.length) {
            NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
            if ([dict isKindOfClass:[NSDictionary class]]) {
                metadata = dict;
            }
        }
        NSDictionary *record = @{
            @"timestamp": @([[NSDate date] timeIntervalSince1970]),
            @"pid": @(getpid()),
            @"component": component ?: @"",
            @"bundleID": bundleID,
            @"processName": processName,
            @"executablePath": exe,
            @"home": home,
            @"arguments": args,
            @"environment": envOut,
            @"containerMetadata": metadata ?: @{}
        };
        mkdir("/var/mobile/Library/ProjectX", 0755);
        NSString *path = @"/var/mobile/Library/ProjectX/webkit_trace.log";
        NSString *line = [[record description] stringByAppendingString:@"\n---\n"];
        NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
        int fd = open(path.UTF8String, O_WRONLY | O_CREAT | O_APPEND, 0644);
        if (fd < 0) fd = open("/tmp/webkit_trace.log", O_WRONLY | O_CREAT | O_APPEND, 0644);
        if (fd < 0) return;
        write(fd, data.bytes, data.length);
        close(fd);
    }
}

static inline void PXFileDebugLoadMarker(const char *component) {
    if (access("/tmp/px_debug_all", F_OK) != 0 && !PXFileDebugAIDA64Enabled() && !PXFileDebugWebKitTraceEnabled()) return;
    const char *prog = getprogname() ?: "<nil>";
    char exePath[512] = {0};
    uint32_t exeSize = sizeof(exePath);
    if (_NSGetExecutablePath(exePath, &exeSize) != 0) {
        strlcpy(exePath, "<unknown>", sizeof(exePath));
    }

    char line[1200];
    int len = snprintf(line, sizeof(line), "pid=%d component=%s prog=%s exe=%s\n", getpid(), component ?: "<nil>", prog, exePath);
    if (len <= 0) return;
    if (len > (int)sizeof(line)) len = (int)sizeof(line);
    PXFileDebugWritePath("/tmp/projectx_loads.log", line, (size_t)len);
}

static inline void PXFileDebugAIDA64Log(const char *fmt, ...) {
    if (!PXFileDebugAIDA64Enabled() || !fmt) return;

    char msg[1024];
    va_list args;
    va_start(args, fmt);
    vsnprintf(msg, sizeof(msg), fmt, args);
    va_end(args);

    struct timeval tv;
    gettimeofday(&tv, NULL);
    struct tm tmv;
    localtime_r(&tv.tv_sec, &tmv);

    char line[1400];
    int len = snprintf(line, sizeof(line),
                       "%02d:%02d:%02d.%03d pid=%d %s\n",
                       tmv.tm_hour, tmv.tm_min, tmv.tm_sec, (int)(tv.tv_usec / 1000),
                       getpid(), msg);
    if (len <= 0) return;
    if (len > (int)sizeof(line)) len = (int)sizeof(line);

    mkdir("/var/mobile/Library/ProjectX", 0755);
    int fd = open("/var/mobile/Library/ProjectX/aida64_debug.log", O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd < 0) fd = open("/tmp/aida64_debug.log", O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd < 0) return;
    write(fd, line, (size_t)len);
    close(fd);
}
