#import "CommandRunner.h"

#import <spawn.h>
#import <sys/wait.h>
#import <sys/select.h>
#import <fcntl.h>
#import <errno.h>

static void PXSetRunnerErrorIfUnset(CommandResult *result, int errorCode) {
    if (result.runnerError == 0) {
        result.runnerError = errorCode != 0 ? errorCode : EIO;
    }
}

static int PXSetFileDescriptorNonBlocking(int fd) {
    int flags = fcntl(fd, F_GETFL);
    if (flags == -1) {
        return errno != 0 ? errno : EIO;
    }
    if (fcntl(fd, F_SETFL, flags | O_NONBLOCK) == -1) {
        return errno != 0 ? errno : EIO;
    }
    return 0;
}

static BOOL PXWaitForChild(pid_t pid, int *waitStatus, int *waitError) {
    pid_t waitResult;
    do {
        waitResult = waitpid(pid, waitStatus, 0);
    } while (waitResult == -1 && errno == EINTR);

    if (waitResult == pid) {
        *waitError = 0;
        return YES;
    }

    *waitError = (waitResult == -1 && errno != 0) ? errno : ECHILD;
    return NO;
}

static void PXApplyWaitStatus(CommandResult *result, int waitStatus) {
    if (WIFEXITED(waitStatus)) {
        result.exitedNormally = YES;
        result.exitCode = WEXITSTATUS(waitStatus);
        result.terminationSignal = 0;
    } else if (WIFSIGNALED(waitStatus)) {
        result.exitedNormally = NO;
        result.exitCode = -1;
        result.terminationSignal = WTERMSIG(waitStatus);
    } else {
        result.runnerError = EINVAL;
        result.exitedNormally = NO;
        result.exitCode = -1;
        result.terminationSignal = 0;
    }
}

@implementation CommandResult

- (instancetype)init {
    self = [super init];
    if (self) {
        _exitCode = -1;
        _stdoutString = @"";
        _stderrString = @"";
        _spawnError = 0;
        _runnerError = 0;
        _terminationSignal = 0;
        _exitedNormally = NO;
        _timedOut = NO;
        _duration = 0;
        _stdoutTruncated = NO;
        _stderrTruncated = NO;
    }
    return self;
}

- (BOOL)isSucceeded {
    return self.spawnError == 0 &&
           self.runnerError == 0 &&
           self.exitedNormally &&
           !self.timedOut &&
           self.terminationSignal == 0 &&
           self.exitCode == 0;
}

@end

@implementation CommandRunner

+ (instancetype)shared {
    static CommandRunner *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (CommandResult *)run:(NSString *)command {
    CommandResult *result = [[CommandResult alloc] init];

    pid_t pid;
    const char *argv[] = {"/bin/sh", "-c", [command UTF8String], NULL};
    int spawnStatus = posix_spawn(&pid, argv[0], NULL, NULL, (char *const *)argv, NULL);
    if (spawnStatus != 0) {
        result.spawnError = spawnStatus;
        return result;
    }

    int waitStatus = 0;
    int waitError = 0;
    if (!PXWaitForChild(pid, &waitStatus, &waitError)) {
        result.runnerError = waitError;
        return result;
    }

    PXApplyWaitStatus(result, waitStatus);
    return result;
}

- (CommandResult *)runAndCapture:(NSString *)command {
    CommandResult *result = [[CommandResult alloc] init];

    int outPipe[2];
    int errPipe[2];
    if (pipe(outPipe) != 0) {
        result.runnerError = errno != 0 ? errno : EIO;
        result.stderrString = @"pipe(out) failed";
        return result;
    }
    if (pipe(errPipe) != 0) {
        int pipeError = errno != 0 ? errno : EIO;
        close(outPipe[0]);
        close(outPipe[1]);
        result.runnerError = pipeError;
        result.stderrString = @"pipe(err) failed";
        return result;
    }

    int nonBlockingError = PXSetFileDescriptorNonBlocking(outPipe[0]);
    if (nonBlockingError == 0) {
        nonBlockingError = PXSetFileDescriptorNonBlocking(errPipe[0]);
    }
    if (nonBlockingError != 0) {
        close(outPipe[0]);
        close(outPipe[1]);
        close(errPipe[0]);
        close(errPipe[1]);
        result.runnerError = nonBlockingError;
        result.stderrString = @"fcntl(pipe) failed";
        return result;
    }

    posix_spawn_file_actions_t actions;
    int actionStatus = posix_spawn_file_actions_init(&actions);
    BOOL actionsInitialized = actionStatus == 0;
    if (actionStatus == 0) actionStatus = posix_spawn_file_actions_adddup2(&actions, outPipe[1], STDOUT_FILENO);
    if (actionStatus == 0) actionStatus = posix_spawn_file_actions_adddup2(&actions, errPipe[1], STDERR_FILENO);
    if (actionStatus == 0) actionStatus = posix_spawn_file_actions_addclose(&actions, outPipe[0]);
    if (actionStatus == 0) actionStatus = posix_spawn_file_actions_addclose(&actions, errPipe[0]);
    if (actionStatus == 0) actionStatus = posix_spawn_file_actions_addclose(&actions, outPipe[1]);
    if (actionStatus == 0) actionStatus = posix_spawn_file_actions_addclose(&actions, errPipe[1]);
    if (actionStatus != 0) {
        if (actionsInitialized) {
            posix_spawn_file_actions_destroy(&actions);
        }
        close(outPipe[0]);
        close(outPipe[1]);
        close(errPipe[0]);
        close(errPipe[1]);
        result.runnerError = actionStatus;
        result.stderrString = @"posix_spawn file actions setup failed";
        return result;
    }

    pid_t pid;
    const char *argv[] = {"/bin/sh", "-c", [command UTF8String], NULL};
    int spawnStatus = posix_spawn(&pid, argv[0], &actions, NULL, (char *const *)argv, NULL);
    posix_spawn_file_actions_destroy(&actions);

    close(outPipe[1]);
    close(errPipe[1]);

    if (spawnStatus != 0) {
        close(outPipe[0]);
        close(errPipe[0]);
        result.spawnError = spawnStatus;
        return result;
    }

    // Prevent deadlocks: drain stdout/stderr concurrently.
    // Without this, a chatty stderr can fill its pipe and block the child while we're still
    // reading stdout (or vice versa).
    int outFd = outPipe[0];
    int errFd = errPipe[0];

    NSMutableData *outData = [NSMutableData data];
    NSMutableData *errData = [NSMutableData data];
    char buffer[4096];

    BOOL outOpen = YES;
    BOOL errOpen = YES;
    while (outOpen || errOpen) {
        fd_set readfds;
        FD_ZERO(&readfds);
        int maxfd = -1;
        if (outOpen) {
            FD_SET(outFd, &readfds);
            if (outFd > maxfd) maxfd = outFd;
        }
        if (errOpen) {
            FD_SET(errFd, &readfds);
            if (errFd > maxfd) maxfd = errFd;
        }

        // 1s timeout to avoid hard hangs.
        struct timeval tv;
        tv.tv_sec = 1;
        tv.tv_usec = 0;

        int sel = select(maxfd + 1, &readfds, NULL, NULL, &tv);
        if (sel < 0) {
            if (errno == EINTR) {
                continue;
            }
            int selectError = errno != 0 ? errno : EIO;
            PXSetRunnerErrorIfUnset(result, selectError);
            break;
        }

        if (sel == 0) {
            continue;
        }

        if (outOpen && FD_ISSET(outFd, &readfds)) {
            for (;;) {
                ssize_t n = read(outFd, buffer, sizeof(buffer));
                if (n > 0) {
                    [outData appendBytes:buffer length:(NSUInteger)n];
                    continue;
                }
                if (n == 0) {
                    close(outFd);
                    outOpen = NO;
                    break;
                }
                if (errno == EINTR) {
                    continue;
                }
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    break;
                }
                int readError = errno != 0 ? errno : EIO;
                PXSetRunnerErrorIfUnset(result, readError);
                close(outFd);
                outOpen = NO;
                break;
            }
        }

        if (errOpen && FD_ISSET(errFd, &readfds)) {
            for (;;) {
                ssize_t n = read(errFd, buffer, sizeof(buffer));
                if (n > 0) {
                    [errData appendBytes:buffer length:(NSUInteger)n];
                    continue;
                }
                if (n == 0) {
                    close(errFd);
                    errOpen = NO;
                    break;
                }
                if (errno == EINTR) {
                    continue;
                }
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    break;
                }
                int readError = errno != 0 ? errno : EIO;
                PXSetRunnerErrorIfUnset(result, readError);
                close(errFd);
                errOpen = NO;
                break;
            }
        }
    }

    if (outOpen) {
        close(outFd);
    }
    if (errOpen) {
        close(errFd);
    }

    int waitStatus = 0;
    int waitError = 0;
    if (PXWaitForChild(pid, &waitStatus, &waitError)) {
        PXApplyWaitStatus(result, waitStatus);
    } else {
        result.runnerError = waitError;
    }

    NSString *stdoutString = [[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding];
    NSString *stderrString = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding];
    result.stdoutString = stdoutString ?: @"";
    result.stderrString = stderrString ?: @"";
    return result;
}

- (NSString *)firstExistingPath:(NSArray<NSString *> *)paths {
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *path in paths) {
        if ([fm fileExistsAtPath:path]) {
            return path;
        }
    }
    return nil;
}

@end
