#import <Foundation/Foundation.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

static inline BOOL PXFileDebugAIDA64Enabled(void) {
    static int enabled = -1;
    if (enabled != -1) return enabled == 1;
    enabled = 0;
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
