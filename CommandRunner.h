#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CommandResult : NSObject
@property (nonatomic, assign) int exitCode;
@property (nonatomic, copy) NSString *stdoutString;
@property (nonatomic, copy) NSString *stderrString;
@property (nonatomic, assign) int spawnError;
@property (nonatomic, assign) int runnerError;
@property (nonatomic, assign) int terminationSignal;
@property (nonatomic, assign) BOOL exitedNormally;
@property (nonatomic, assign) BOOL timedOut;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) BOOL stdoutTruncated;
@property (nonatomic, assign) BOOL stderrTruncated;
@property (nonatomic, readonly, getter=isSucceeded) BOOL succeeded;
@end

@interface CommandRunner : NSObject
+ (instancetype)shared;

// Runs a command using /bin/sh -c.
// stdout/stderr capture depends on method used.
- (CommandResult *)run:(NSString *)command;
- (CommandResult *)runAndCapture:(NSString *)command;
- (CommandResult *)runAndCapture:(NSString *)command
                     timeoutSec:(NSTimeInterval)timeoutSec
                 maxOutputBytes:(NSUInteger)maxOutputBytes;
- (CommandResult *)runExecutableAndCapture:(NSString *)executablePath
                                 arguments:(NSArray<NSString *> *)arguments
                                timeoutSec:(NSTimeInterval)timeoutSec
                            maxOutputBytes:(NSUInteger)maxOutputBytes;

- (nullable NSString *)firstExistingPath:(NSArray<NSString *> *)paths;

@end

NS_ASSUME_NONNULL_END
