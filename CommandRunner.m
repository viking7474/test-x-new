#import "CommandRunner.h"

#import <spawn.h>
#import <sys/wait.h>
#import <sys/select.h>
#import <fcntl.h>
#import <errno.h>
#import <signal.h>
#import <time.h>
#import <unistd.h>
#import <math.h>
#import <float.h>

static const NSTimeInterval PXCapturePollQuantumSec = 0.05;
static const NSTimeInterval PXTerminationGraceSec = 0.35;
static const NSTimeInterval PXKillReapGraceSec = 0.75;
static const NSUInteger PXDrainBytesPerCycle = 64 * 1024;

typedef struct {
    BOOL deadlineEnabled;
    NSTimeInterval timeoutSec;
    BOOL outputCapEnabled;
    NSUInteger maxOutputBytes;
    BOOL processGroupEnabled;
} PXCaptureOptions;

typedef struct {
    BOOL reaped;
    BOOL stateUnavailable;
} PXChildState;

typedef struct {
    BOOL enabled;
    BOOL configured;
    pid_t childPID;
    pid_t processGroupID;
    int lastGroupSignal;
    BOOL finalGroupSignalSent;
} PXProcessGroupState;

static void PXSetRunnerErrorIfUnset(CommandResult *result, int errorCode) {
    if (result.runnerError == 0) {
        result.runnerError = errorCode != 0 ? errorCode : EIO;
    }
}

static void PXSetCriticalRunnerError(CommandResult *result, int errorCode) {
    result.runnerError = errorCode != 0 ? errorCode : EIO;
}

static void PXCloseFileDescriptor(int *fd) {
    if (*fd >= 0) {
        close(*fd);
        *fd = -1;
    }
}

static int PXMonotonicTime(struct timespec *value) {
    if (clock_gettime(CLOCK_MONOTONIC, value) == 0) {
        return 0;
    }
    return errno != 0 ? errno : EIO;
}

static NSTimeInterval PXMonotonicSeconds(const struct timespec *value) {
    return (NSTimeInterval)value->tv_sec + ((NSTimeInterval)value->tv_nsec / 1000000000.0);
}

static CommandResult *PXFinishResult(CommandResult *result, const struct timespec *startTime) {
    struct timespec endTime;
    int clockError = PXMonotonicTime(&endTime);
    if (clockError != 0) {
        PXSetRunnerErrorIfUnset(result, clockError);
        result.duration = 0;
        return result;
    }

    NSTimeInterval duration = PXMonotonicSeconds(&endTime) - PXMonotonicSeconds(startTime);
    if (!isfinite(duration) || duration < 0) {
        PXSetRunnerErrorIfUnset(result, EIO);
        duration = 0;
    }
    result.duration = duration;
    return result;
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
        PXSetCriticalRunnerError(result, EINVAL);
        result.exitedNormally = NO;
        result.exitCode = -1;
        result.terminationSignal = 0;
    }
}

static BOOL PXPollChild(pid_t pid,
                        PXChildState *childState,
                        CommandResult *result) {
    if (childState->reaped || childState->stateUnavailable) {
        return !childState->stateUnavailable;
    }

    int waitStatus = 0;
    pid_t waitResult = waitpid(pid, &waitStatus, WNOHANG);
    if (waitResult == pid) {
        childState->reaped = YES;
        PXApplyWaitStatus(result, waitStatus);
        return YES;
    }
    if (waitResult == 0) {
        return YES;
    }
    if (waitResult == -1 && errno == EINTR) {
        return YES;
    }

    childState->stateUnavailable = YES;
    PXSetCriticalRunnerError(result, (waitResult == -1 && errno != 0) ? errno : ECHILD);
    return NO;
}

static int PXDestroySpawnAttributes(posix_spawnattr_t *attributes,
                                    BOOL *attributesInitialized) {
    if (!*attributesInitialized) {
        return 0;
    }

    int destroyStatus = posix_spawnattr_destroy(attributes);
    *attributesInitialized = NO;
    return destroyStatus;
}

static BOOL PXValidateOwnedProcessGroup(const PXProcessGroupState *groupState,
                                        pid_t spawnedChildPID,
                                        CommandResult *result) {
    pid_t runnerProcessGroup = getpgrp();
    BOOL valid = groupState->enabled &&
                 groupState->configured &&
                 groupState->processGroupID > 1 &&
                 groupState->childPID == spawnedChildPID &&
                 groupState->processGroupID == spawnedChildPID &&
                 groupState->processGroupID != runnerProcessGroup;
    if (!valid) {
        PXSetRunnerErrorIfUnset(result, EINVAL);
    }
    return valid;
}

static BOOL PXSignalOwnedProcessGroup(PXProcessGroupState *groupState,
                                      pid_t spawnedChildPID,
                                      const PXChildState *childState,
                                      int signalNumber,
                                      BOOL finalSignal,
                                      CommandResult *result) {
    if (childState->reaped || groupState->finalGroupSignalSent) {
        PXSetRunnerErrorIfUnset(result, EINVAL);
        return NO;
    }
    if (!PXValidateOwnedProcessGroup(groupState, spawnedChildPID, result)) {
        return NO;
    }

    int signalStatus = kill(-groupState->processGroupID, signalNumber);
    int signalError = signalStatus == 0 ? 0 : errno;

    groupState->lastGroupSignal = signalNumber;
    if (finalSignal) {
        groupState->finalGroupSignalSent = YES;
    }

    if (signalStatus != 0 && signalError != ESRCH) {
        PXSetRunnerErrorIfUnset(result, signalError != 0 ? signalError : EIO);
    }
    return YES;
}

static BOOL PXAppendCapturedBytes(NSMutableData *data,
                                  const void *bytes,
                                  NSUInteger length,
                                  const PXCaptureOptions *options,
                                  BOOL truncated) {
    if (!options->outputCapEnabled) {
        [data appendBytes:bytes length:length];
        return truncated;
    }

    NSUInteger retainedLength = data.length;
    NSUInteger remaining = retainedLength < options->maxOutputBytes
        ? options->maxOutputBytes - retainedLength
        : 0;
    NSUInteger keepLength = MIN(length, remaining);
    if (keepLength > 0) {
        [data appendBytes:bytes length:keepLength];
    }
    return truncated || keepLength < length;
}

static void PXDrainStream(int *fd,
                          BOOL *isOpen,
                          NSMutableData *data,
                          const PXCaptureOptions *options,
                          BOOL stdoutStream,
                          CommandResult *result) {
    if (!*isOpen || *fd < 0) {
        return;
    }

    char buffer[4096];
    NSUInteger drainedThisCycle = 0;
    NSUInteger interruptedReads = 0;

    while (drainedThisCycle < PXDrainBytesPerCycle) {
        ssize_t readLength = read(*fd, buffer, sizeof(buffer));
        if (readLength > 0) {
            NSUInteger chunkLength = (NSUInteger)readLength;
            BOOL truncated = stdoutStream ? result.stdoutTruncated : result.stderrTruncated;
            truncated = PXAppendCapturedBytes(data,
                                              buffer,
                                              chunkLength,
                                              options,
                                              truncated);
            if (stdoutStream) {
                result.stdoutTruncated = truncated;
            } else {
                result.stderrTruncated = truncated;
            }
            drainedThisCycle += chunkLength;
            interruptedReads = 0;
            continue;
        }

        if (readLength == 0) {
            PXCloseFileDescriptor(fd);
            *isOpen = NO;
            return;
        }

        int readError = errno;
        if (readError == EINTR) {
            interruptedReads++;
            if (interruptedReads < 4) {
                continue;
            }
            return;
        }
        if (readError == EAGAIN || readError == EWOULDBLOCK) {
            return;
        }

        PXSetRunnerErrorIfUnset(result, readError != 0 ? readError : EIO);
        PXCloseFileDescriptor(fd);
        *isOpen = NO;
        return;
    }
}

static void PXDrainAvailableStreams(int *outFd,
                                    BOOL *outOpen,
                                    NSMutableData *outData,
                                    int *errFd,
                                    BOOL *errOpen,
                                    NSMutableData *errData,
                                    const PXCaptureOptions *options,
                                    CommandResult *result) {
    PXDrainStream(outFd,
                  outOpen,
                  outData,
                  options,
                  YES,
                  result);
    PXDrainStream(errFd,
                  errOpen,
                  errData,
                  options,
                  NO,
                  result);
}

static BOOL PXWaitForReadable(int outFd,
                              BOOL outOpen,
                              int errFd,
                              BOOL errOpen,
                              NSTimeInterval waitSec,
                              BOOL *outReady,
                              BOOL *errReady,
                              CommandResult *result) {
    *outReady = NO;
    *errReady = NO;

    if ((outOpen && outFd >= FD_SETSIZE) ||
        (errOpen && errFd >= FD_SETSIZE)) {
        PXSetRunnerErrorIfUnset(result, EINVAL);
        return NO;
    }

    fd_set readfds;
    FD_ZERO(&readfds);
    int maxfd = -1;
    if (outOpen && outFd >= 0) {
        FD_SET(outFd, &readfds);
        maxfd = outFd;
    }
    if (errOpen && errFd >= 0) {
        FD_SET(errFd, &readfds);
        if (errFd > maxfd) {
            maxfd = errFd;
        }
    }

    if (!isfinite(waitSec) || waitSec < 0) {
        waitSec = 0;
    }

    struct timeval timeout;
    timeout.tv_sec = (time_t)waitSec;
    NSTimeInterval fractional = waitSec - (NSTimeInterval)timeout.tv_sec;
    timeout.tv_usec = (suseconds_t)(fractional * 1000000.0);
    if (waitSec > 0 && timeout.tv_sec == 0 && timeout.tv_usec == 0) {
        timeout.tv_usec = 1;
    }

    int selectResult = select(maxfd + 1,
                              maxfd >= 0 ? &readfds : NULL,
                              NULL,
                              NULL,
                              &timeout);
    if (selectResult < 0) {
        if (errno == EINTR) {
            return YES;
        }
        PXSetRunnerErrorIfUnset(result, errno != 0 ? errno : EIO);
        return NO;
    }

    if (selectResult > 0) {
        *outReady = outOpen && outFd >= 0 && FD_ISSET(outFd, &readfds);
        *errReady = errOpen && errFd >= 0 && FD_ISSET(errFd, &readfds);
    }
    return YES;
}

static NSString *PXStringFromCapturedData(NSData *data) {
    if (data.length == 0) {
        return @"";
    }

    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (string) {
        return string;
    }

    NSUInteger maxTrim = MIN((NSUInteger)3, data.length);
    for (NSUInteger trim = 1; trim <= maxTrim; trim++) {
        NSUInteger prefixLength = data.length - trim;
        string = [[NSString alloc] initWithBytes:data.bytes
                                          length:prefixLength
                                        encoding:NSUTF8StringEncoding];
        if (string) {
            return string;
        }
    }

    string = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    return string ?: @"";
}

static void PXAssignCapturedStrings(CommandResult *result,
                                    NSData *outData,
                                    NSData *errData) {
    result.stdoutString = PXStringFromCapturedData(outData);
    result.stderrString = PXStringFromCapturedData(errData);
}

static void PXRunBoundedDrainPhase(NSTimeInterval phaseDuration,
                                   int *outFd,
                                   BOOL *outOpen,
                                   NSMutableData *outData,
                                   int *errFd,
                                   BOOL *errOpen,
                                   NSMutableData *errData,
                                   const PXCaptureOptions *options,
                                   CommandResult *result) {
    struct timespec phaseStartTime;
    int clockError = PXMonotonicTime(&phaseStartTime);
    BOOL clockAvailable = clockError == 0;
    if (!clockAvailable) {
        PXSetRunnerErrorIfUnset(result, clockError);
    }

    NSTimeInterval phaseDeadline = clockAvailable
        ? PXMonotonicSeconds(&phaseStartTime) + phaseDuration
        : 0;
    NSUInteger maxAttempts = (NSUInteger)ceil(phaseDuration / PXCapturePollQuantumSec) + 2;

    for (NSUInteger attempt = 0; attempt < maxAttempts; attempt++) {
        PXDrainAvailableStreams(outFd,
                                outOpen,
                                outData,
                                errFd,
                                errOpen,
                                errData,
                                options,
                                result);

        NSTimeInterval waitSec = PXCapturePollQuantumSec;
        if (clockAvailable) {
            struct timespec nowTime;
            int nowError = PXMonotonicTime(&nowTime);
            if (nowError != 0) {
                PXSetRunnerErrorIfUnset(result, nowError);
                clockAvailable = NO;
            } else {
                NSTimeInterval remaining = phaseDeadline - PXMonotonicSeconds(&nowTime);
                if (remaining <= 0) {
                    break;
                }
                waitSec = MIN(waitSec, remaining);
            }
        }

        BOOL outReady = NO;
        BOOL errReady = NO;
        if (!PXWaitForReadable(*outFd,
                               *outOpen,
                               *errFd,
                               *errOpen,
                               waitSec,
                               &outReady,
                               &errReady,
                               result)) {
            PXCloseFileDescriptor(outFd);
            PXCloseFileDescriptor(errFd);
            *outOpen = NO;
            *errOpen = NO;
            continue;
        }

        if (outReady) {
            PXDrainStream(outFd,
                          outOpen,
                          outData,
                          options,
                          YES,
                          result);
        }
        if (errReady) {
            PXDrainStream(errFd,
                          errOpen,
                          errData,
                          options,
                          NO,
                          result);
        }
    }
}

static void PXRunBoundedReapPhase(pid_t pid,
                                  NSTimeInterval phaseDuration,
                                  PXChildState *childState,
                                  int *outFd,
                                  BOOL *outOpen,
                                  NSMutableData *outData,
                                  int *errFd,
                                  BOOL *errOpen,
                                  NSMutableData *errData,
                                  const PXCaptureOptions *options,
                                  CommandResult *result) {
    struct timespec phaseStartTime;
    int clockError = PXMonotonicTime(&phaseStartTime);
    BOOL clockAvailable = clockError == 0;
    if (!clockAvailable) {
        PXSetRunnerErrorIfUnset(result, clockError);
    }

    NSTimeInterval phaseDeadline = clockAvailable
        ? PXMonotonicSeconds(&phaseStartTime) + phaseDuration
        : 0;
    NSUInteger maxAttempts = (NSUInteger)ceil(phaseDuration / PXCapturePollQuantumSec) + 2;

    for (NSUInteger attempt = 0;
         attempt < maxAttempts && !childState->reaped && !childState->stateUnavailable;
         attempt++) {
        if (!PXPollChild(pid, childState, result)) {
            break;
        }

        PXDrainAvailableStreams(outFd,
                                outOpen,
                                outData,
                                errFd,
                                errOpen,
                                errData,
                                options,
                                result);

        if (childState->reaped || childState->stateUnavailable) {
            break;
        }

        NSTimeInterval waitSec = PXCapturePollQuantumSec;
        if (clockAvailable) {
            struct timespec nowTime;
            int nowError = PXMonotonicTime(&nowTime);
            if (nowError != 0) {
                PXSetRunnerErrorIfUnset(result, nowError);
                clockAvailable = NO;
            } else {
                NSTimeInterval remaining = phaseDeadline - PXMonotonicSeconds(&nowTime);
                if (remaining <= 0) {
                    break;
                }
                waitSec = MIN(waitSec, remaining);
            }
        }

        BOOL outReady = NO;
        BOOL errReady = NO;
        if (!PXWaitForReadable(*outFd,
                               *outOpen,
                               *errFd,
                               *errOpen,
                               waitSec,
                               &outReady,
                               &errReady,
                               result)) {
            PXCloseFileDescriptor(outFd);
            PXCloseFileDescriptor(errFd);
            *outOpen = NO;
            *errOpen = NO;
            continue;
        }

        if (outReady) {
            PXDrainStream(outFd,
                          outOpen,
                          outData,
                          options,
                          YES,
                          result);
        }
        if (errReady) {
            PXDrainStream(errFd,
                          errOpen,
                          errData,
                          options,
                          NO,
                          result);
        }
    }
}

static void PXFinalizeCaptureDescriptors(int *outFd,
                                         BOOL *outOpen,
                                         NSMutableData *outData,
                                         int *errFd,
                                         BOOL *errOpen,
                                         NSMutableData *errData,
                                         const PXCaptureOptions *options,
                                         CommandResult *result) {
    PXDrainAvailableStreams(outFd,
                            outOpen,
                            outData,
                            errFd,
                            errOpen,
                            errData,
                            options,
                            result);
    PXCloseFileDescriptor(outFd);
    PXCloseFileDescriptor(errFd);
    *outOpen = NO;
    *errOpen = NO;
}

static void PXTerminateDirectChildEmergency(pid_t pid,
                                            PXChildState *childState,
                                            int *outFd,
                                            BOOL *outOpen,
                                            NSMutableData *outData,
                                            int *errFd,
                                            BOOL *errOpen,
                                            NSMutableData *errData,
                                            const PXCaptureOptions *options,
                                            CommandResult *result) {
    if (pid <= 1 || pid == getpid()) {
        PXSetRunnerErrorIfUnset(result, EINVAL);
        PXFinalizeCaptureDescriptors(outFd,
                                     outOpen,
                                     outData,
                                     errFd,
                                     errOpen,
                                     errData,
                                     options,
                                     result);
        return;
    }

    if (!childState->reaped && !childState->stateUnavailable) {
        (void)PXPollChild(pid, childState, result);
    }

    if (!childState->reaped && !childState->stateUnavailable) {
        if (kill(pid, SIGTERM) != 0 && errno != ESRCH) {
            PXSetRunnerErrorIfUnset(result, errno != 0 ? errno : EIO);
        }
        PXRunBoundedReapPhase(pid,
                              PXTerminationGraceSec,
                              childState,
                              outFd,
                              outOpen,
                              outData,
                              errFd,
                              errOpen,
                              errData,
                              options,
                              result);
    }

    if (!childState->reaped && !childState->stateUnavailable) {
        if (kill(pid, SIGKILL) != 0 && errno != ESRCH) {
            PXSetRunnerErrorIfUnset(result, errno != 0 ? errno : EIO);
        }
        PXRunBoundedReapPhase(pid,
                              PXKillReapGraceSec,
                              childState,
                              outFd,
                              outOpen,
                              outData,
                              errFd,
                              errOpen,
                              errData,
                              options,
                              result);
    }

    if (!childState->reaped && !childState->stateUnavailable) {
        PXSetRunnerErrorIfUnset(result, ETIMEDOUT);
    }

    PXFinalizeCaptureDescriptors(outFd,
                                 outOpen,
                                 outData,
                                 errFd,
                                 errOpen,
                                 errData,
                                 options,
                                 result);
}

static void PXTerminateSpawnedCommand(pid_t pid,
                                      BOOL markTimedOut,
                                      PXProcessGroupState *groupState,
                                      PXChildState *childState,
                                      int *outFd,
                                      BOOL *outOpen,
                                      NSMutableData *outData,
                                      int *errFd,
                                      BOOL *errOpen,
                                      NSMutableData *errData,
                                      const PXCaptureOptions *options,
                                      CommandResult *result) {
    if (markTimedOut) {
        result.timedOut = YES;
    }

    if (childState->reaped) {
        PXSetRunnerErrorIfUnset(result, EINVAL);
        PXTerminateDirectChildEmergency(pid,
                                        childState,
                                        outFd,
                                        outOpen,
                                        outData,
                                        errFd,
                                        errOpen,
                                        errData,
                                        options,
                                        result);
        return;
    }

    if (!PXValidateOwnedProcessGroup(groupState, pid, result)) {
        PXTerminateDirectChildEmergency(pid,
                                        childState,
                                        outFd,
                                        outOpen,
                                        outData,
                                        errFd,
                                        errOpen,
                                        errData,
                                        options,
                                        result);
        return;
    }

    if (!PXSignalOwnedProcessGroup(groupState,
                                   pid,
                                   childState,
                                   SIGTERM,
                                   NO,
                                   result)) {
        PXTerminateDirectChildEmergency(pid,
                                        childState,
                                        outFd,
                                        outOpen,
                                        outData,
                                        errFd,
                                        errOpen,
                                        errData,
                                        options,
                                        result);
        return;
    }

    PXRunBoundedDrainPhase(PXTerminationGraceSec,
                           outFd,
                           outOpen,
                           outData,
                           errFd,
                           errOpen,
                           errData,
                           options,
                           result);

    if (!PXSignalOwnedProcessGroup(groupState,
                                   pid,
                                   childState,
                                   SIGKILL,
                                   YES,
                                   result)) {
        PXTerminateDirectChildEmergency(pid,
                                        childState,
                                        outFd,
                                        outOpen,
                                        outData,
                                        errFd,
                                        errOpen,
                                        errData,
                                        options,
                                        result);
        return;
    }

    PXRunBoundedReapPhase(pid,
                          PXKillReapGraceSec,
                          childState,
                          outFd,
                          outOpen,
                          outData,
                          errFd,
                          errOpen,
                          errData,
                          options,
                          result);

    if (!childState->reaped && !childState->stateUnavailable) {
        PXSetRunnerErrorIfUnset(result, ETIMEDOUT);
    }

    PXFinalizeCaptureDescriptors(outFd,
                                 outOpen,
                                 outData,
                                 errFd,
                                 errOpen,
                                 errData,
                                 options,
                                 result);
}

static CommandResult *PXRunCaptureCommand(NSString *command,
                                          PXCaptureOptions options) {
    CommandResult *result = [[CommandResult alloc] init];
    struct timespec startTime;
    int startClockError = PXMonotonicTime(&startTime);
    if (startClockError != 0) {
        result.runnerError = startClockError;
        result.duration = 0;
        return result;
    }

    if (options.deadlineEnabled) {
        if (!isfinite(options.timeoutSec) || options.timeoutSec <= 0 ||
            !options.outputCapEnabled || options.maxOutputBytes == 0) {
            result.runnerError = EINVAL;
            return PXFinishResult(result, &startTime);
        }
    }

    if (!command) {
        result.runnerError = EINVAL;
        return PXFinishResult(result, &startTime);
    }

    const char *commandUTF8 = [command UTF8String];
    if (!commandUTF8) {
        result.runnerError = EINVAL;
        return PXFinishResult(result, &startTime);
    }

    NSTimeInterval deadline = 0;
    if (options.deadlineEnabled) {
        deadline = PXMonotonicSeconds(&startTime) + options.timeoutSec;
        if (!isfinite(deadline)) {
            deadline = DBL_MAX;
        }
    }

    int outPipe[2] = {-1, -1};
    int errPipe[2] = {-1, -1};
    if (pipe(outPipe) != 0) {
        result.runnerError = errno != 0 ? errno : EIO;
        result.stderrString = @"pipe(out) failed";
        return PXFinishResult(result, &startTime);
    }
    if (pipe(errPipe) != 0) {
        int pipeError = errno != 0 ? errno : EIO;
        PXCloseFileDescriptor(&outPipe[0]);
        PXCloseFileDescriptor(&outPipe[1]);
        result.runnerError = pipeError;
        result.stderrString = @"pipe(err) failed";
        return PXFinishResult(result, &startTime);
    }

    int nonBlockingError = PXSetFileDescriptorNonBlocking(outPipe[0]);
    if (nonBlockingError == 0) {
        nonBlockingError = PXSetFileDescriptorNonBlocking(errPipe[0]);
    }
    if (nonBlockingError != 0) {
        PXCloseFileDescriptor(&outPipe[0]);
        PXCloseFileDescriptor(&outPipe[1]);
        PXCloseFileDescriptor(&errPipe[0]);
        PXCloseFileDescriptor(&errPipe[1]);
        result.runnerError = nonBlockingError;
        result.stderrString = @"fcntl(pipe) failed";
        return PXFinishResult(result, &startTime);
    }

    posix_spawnattr_t attributes = {0};
    BOOL attributesInitialized = NO;
    int attributeStatus = 0;
    if (options.processGroupEnabled) {
        attributeStatus = posix_spawnattr_init(&attributes);
        attributesInitialized = attributeStatus == 0;
        if (attributeStatus == 0) {
            attributeStatus = posix_spawnattr_setflags(&attributes, POSIX_SPAWN_SETPGROUP);
        }
        if (attributeStatus == 0) {
            attributeStatus = posix_spawnattr_setpgroup(&attributes, 0);
        }
        if (attributeStatus != 0) {
            result.runnerError = attributeStatus;
            int attributeDestroyStatus = PXDestroySpawnAttributes(&attributes,
                                                                  &attributesInitialized);
            if (attributeDestroyStatus != 0) {
                PXSetRunnerErrorIfUnset(result, attributeDestroyStatus);
            }
            PXCloseFileDescriptor(&outPipe[0]);
            PXCloseFileDescriptor(&outPipe[1]);
            PXCloseFileDescriptor(&errPipe[0]);
            PXCloseFileDescriptor(&errPipe[1]);
            result.stderrString = @"posix_spawn attributes setup failed";
            return PXFinishResult(result, &startTime);
        }
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
        result.runnerError = actionStatus;
        if (actionsInitialized) {
            int actionDestroyStatus = posix_spawn_file_actions_destroy(&actions);
            if (actionDestroyStatus != 0) {
                PXSetRunnerErrorIfUnset(result, actionDestroyStatus);
            }
        }
        int attributeDestroyStatus = PXDestroySpawnAttributes(&attributes,
                                                              &attributesInitialized);
        if (attributeDestroyStatus != 0) {
            PXSetRunnerErrorIfUnset(result, attributeDestroyStatus);
        }
        PXCloseFileDescriptor(&outPipe[0]);
        PXCloseFileDescriptor(&outPipe[1]);
        PXCloseFileDescriptor(&errPipe[0]);
        PXCloseFileDescriptor(&errPipe[1]);
        result.stderrString = @"posix_spawn file actions setup failed";
        return PXFinishResult(result, &startTime);
    }

    if (options.deadlineEnabled) {
        struct timespec beforeSpawnTime;
        int beforeSpawnError = PXMonotonicTime(&beforeSpawnTime);
        if (beforeSpawnError != 0) {
            result.runnerError = beforeSpawnError;
            int actionDestroyStatus = posix_spawn_file_actions_destroy(&actions);
            if (actionDestroyStatus != 0) {
                PXSetRunnerErrorIfUnset(result, actionDestroyStatus);
            }
            int attributeDestroyStatus = PXDestroySpawnAttributes(&attributes,
                                                                  &attributesInitialized);
            if (attributeDestroyStatus != 0) {
                PXSetRunnerErrorIfUnset(result, attributeDestroyStatus);
            }
            PXCloseFileDescriptor(&outPipe[0]);
            PXCloseFileDescriptor(&outPipe[1]);
            PXCloseFileDescriptor(&errPipe[0]);
            PXCloseFileDescriptor(&errPipe[1]);
            return PXFinishResult(result, &startTime);
        }
        if (PXMonotonicSeconds(&beforeSpawnTime) >= deadline) {
            result.timedOut = YES;
            int actionDestroyStatus = posix_spawn_file_actions_destroy(&actions);
            if (actionDestroyStatus != 0) {
                PXSetRunnerErrorIfUnset(result, actionDestroyStatus);
            }
            int attributeDestroyStatus = PXDestroySpawnAttributes(&attributes,
                                                                  &attributesInitialized);
            if (attributeDestroyStatus != 0) {
                PXSetRunnerErrorIfUnset(result, attributeDestroyStatus);
            }
            PXCloseFileDescriptor(&outPipe[0]);
            PXCloseFileDescriptor(&outPipe[1]);
            PXCloseFileDescriptor(&errPipe[0]);
            PXCloseFileDescriptor(&errPipe[1]);
            return PXFinishResult(result, &startTime);
        }
    }

    pid_t pid = -1;
    PXProcessGroupState groupState = {
        options.processGroupEnabled,
        NO,
        -1,
        -1,
        0,
        NO
    };
    const char *argv[] = {"/bin/sh", "-c", commandUTF8, NULL};
    const posix_spawnattr_t *spawnAttributes = attributesInitialized ? &attributes : NULL;
    int spawnStatus = posix_spawn(&pid,
                                  argv[0],
                                  &actions,
                                  spawnAttributes,
                                  (char *const *)argv,
                                  NULL);
    if (spawnStatus == 0) {
        groupState.childPID = pid;
        if (options.processGroupEnabled && pid > 1) {
            groupState.configured = YES;
            groupState.processGroupID = pid;
        } else if (options.processGroupEnabled) {
            PXSetRunnerErrorIfUnset(result, EINVAL);
        }
    }

    int actionDestroyStatus = posix_spawn_file_actions_destroy(&actions);
    if (actionDestroyStatus != 0) {
        PXSetRunnerErrorIfUnset(result, actionDestroyStatus);
    }
    int attributeDestroyStatus = PXDestroySpawnAttributes(&attributes,
                                                          &attributesInitialized);
    if (attributeDestroyStatus != 0) {
        PXSetRunnerErrorIfUnset(result, attributeDestroyStatus);
    }

    PXCloseFileDescriptor(&outPipe[1]);
    PXCloseFileDescriptor(&errPipe[1]);

    if (spawnStatus != 0) {
        PXCloseFileDescriptor(&outPipe[0]);
        PXCloseFileDescriptor(&errPipe[0]);
        result.spawnError = spawnStatus;
        return PXFinishResult(result, &startTime);
    }

    int outFd = outPipe[0];
    int errFd = errPipe[0];
    BOOL outOpen = YES;
    BOOL errOpen = YES;
    NSMutableData *outData = [NSMutableData data];
    NSMutableData *errData = [NSMutableData data];
    PXChildState childState = {NO, NO};
    BOOL deadlineExpired = NO;
    BOOL timingFailure = NO;

    while (!childState.stateUnavailable &&
           (!childState.reaped || outOpen || errOpen)) {
        BOOL capturePipeOpen = outOpen || errOpen;
        BOOL mayReapDirectChild = !options.processGroupEnabled || !capturePipeOpen;
        if (mayReapDirectChild && !PXPollChild(pid, &childState, result)) {
            break;
        }

        PXDrainAvailableStreams(&outFd,
                                &outOpen,
                                outData,
                                &errFd,
                                &errOpen,
                                errData,
                                &options,
                                result);

        if (options.processGroupEnabled &&
            capturePipeOpen &&
            !outOpen &&
            !errOpen &&
            !childState.reaped &&
            !PXPollChild(pid, &childState, result)) {
            break;
        }

        if (childState.reaped && !outOpen && !errOpen) {
            break;
        }

        NSTimeInterval waitSec = PXCapturePollQuantumSec;
        if (options.deadlineEnabled) {
            struct timespec nowTime;
            int nowError = PXMonotonicTime(&nowTime);
            if (nowError != 0) {
                PXSetRunnerErrorIfUnset(result, nowError);
                timingFailure = YES;
                break;
            }

            NSTimeInterval remaining = deadline - PXMonotonicSeconds(&nowTime);
            if (remaining <= 0) {
                deadlineExpired = YES;
                break;
            }
            waitSec = MIN(waitSec, remaining);
        }

        BOOL outReady = NO;
        BOOL errReady = NO;
        if (!PXWaitForReadable(outFd,
                               outOpen,
                               errFd,
                               errOpen,
                               waitSec,
                               &outReady,
                               &errReady,
                               result)) {
            PXCloseFileDescriptor(&outFd);
            PXCloseFileDescriptor(&errFd);
            outOpen = NO;
            errOpen = NO;
            continue;
        }

        if (outReady) {
            PXDrainStream(&outFd,
                          &outOpen,
                          outData,
                          &options,
                          YES,
                          result);
        }
        if (errReady) {
            PXDrainStream(&errFd,
                          &errOpen,
                          errData,
                          &options,
                          NO,
                          result);
        }
    }

    if (deadlineExpired) {
        PXTerminateSpawnedCommand(pid,
                                  YES,
                                  &groupState,
                                  &childState,
                                  &outFd,
                                  &outOpen,
                                  outData,
                                  &errFd,
                                  &errOpen,
                                  errData,
                                  &options,
                                  result);
    } else if (timingFailure && !childState.reaped && !childState.stateUnavailable) {
        PXTerminateSpawnedCommand(pid,
                                  NO,
                                  &groupState,
                                  &childState,
                                  &outFd,
                                  &outOpen,
                                  outData,
                                  &errFd,
                                  &errOpen,
                                  errData,
                                  &options,
                                  result);
    } else {
        PXFinalizeCaptureDescriptors(&outFd,
                                     &outOpen,
                                     outData,
                                     &errFd,
                                     &errOpen,
                                     errData,
                                     &options,
                                     result);
    }

    PXAssignCapturedStrings(result, outData, errData);
    return PXFinishResult(result, &startTime);
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
    struct timespec startTime;
    int startClockError = PXMonotonicTime(&startTime);
    if (startClockError != 0) {
        result.runnerError = startClockError;
        result.duration = 0;
        return result;
    }

    if (!command) {
        result.runnerError = EINVAL;
        return PXFinishResult(result, &startTime);
    }

    const char *commandUTF8 = [command UTF8String];
    if (!commandUTF8) {
        result.runnerError = EINVAL;
        return PXFinishResult(result, &startTime);
    }

    pid_t pid;
    const char *argv[] = {"/bin/sh", "-c", commandUTF8, NULL};
    int spawnStatus = posix_spawn(&pid,
                                  argv[0],
                                  NULL,
                                  NULL,
                                  (char *const *)argv,
                                  NULL);
    if (spawnStatus != 0) {
        result.spawnError = spawnStatus;
        return PXFinishResult(result, &startTime);
    }

    int waitStatus = 0;
    int waitError = 0;
    if (!PXWaitForChild(pid, &waitStatus, &waitError)) {
        result.runnerError = waitError;
        return PXFinishResult(result, &startTime);
    }

    PXApplyWaitStatus(result, waitStatus);
    return PXFinishResult(result, &startTime);
}

- (CommandResult *)runAndCapture:(NSString *)command {
    PXCaptureOptions options;
    options.deadlineEnabled = NO;
    options.timeoutSec = 0;
    options.outputCapEnabled = NO;
    options.maxOutputBytes = 0;
    options.processGroupEnabled = NO;
    return PXRunCaptureCommand(command, options);
}

- (CommandResult *)runAndCapture:(NSString *)command
                     timeoutSec:(NSTimeInterval)timeoutSec
                 maxOutputBytes:(NSUInteger)maxOutputBytes {
    PXCaptureOptions options;
    options.deadlineEnabled = YES;
    options.timeoutSec = timeoutSec;
    options.outputCapEnabled = YES;
    options.maxOutputBytes = maxOutputBytes;
    options.processGroupEnabled = YES;
    return PXRunCaptureCommand(command, options);
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
