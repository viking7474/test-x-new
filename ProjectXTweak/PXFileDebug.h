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

static inline BOOL PXFileDebugAIDA64Enabled(void) {
    static int enabled = -1;
    if (enabled != -1) return enabled == 1;
    enabled = 0;

    if (access("/tmp/px_debug_all", F_OK) == 0) {
        enabled = 1;
        return YES;
    }

    const char *prog = getprogname();
    if (PXFileDebugContainsNoCase(prog, "aida")) {
        enabled = 1;
        return YES;
    }

    char exePath[1024] = {0};
    uint32_t exeSize = sizeof(exePath);
    if (_NSGetExecutablePath(exePath, &exeSize) == 0 && PXFileDebugContainsNoCase(exePath, "aida")) {
        enabled = 1;
        return YES;
    }

    @autoreleasepool {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        NSString *processName = [NSProcessInfo processInfo].processName;
        if ([bundleID isEqualToString:@"com.finalwire.aida64"] ||
            [processName rangeOfString:@"aida" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            enabled = 1;
        }
    }
    return enabled == 1;
}

static inline void PXFileDebugLoadMarker(const char *component) {
    if (access("/tmp/px_debug_all", F_OK) != 0 && !PXFileDebugAIDA64Enabled()) return;
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
