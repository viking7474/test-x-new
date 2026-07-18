#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "PXMainDataRestoreTransaction.h"
#import "PXAppGroupRestoreTransaction.h"
#import "PXOptionalRestoreTransaction.h"
#import "PXResolvedContainer.h"
#import "PXMainDataStaging.h"
#import "PXOptionalRestoreStaging.h"
#import "PXAppGroupRestoreTargetPlan.h"
#import "PXDestructivePathValidator.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <pthread.h>
#include <signal.h>
#include <spawn.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

#if (PXFI_DOMAIN_MAIN + PXFI_DOMAIN_APP_GROUP + PXFI_DOMAIN_OPTIONAL) != 1
#error Exactly one PXFI_DOMAIN_MAIN, PXFI_DOMAIN_APP_GROUP or PXFI_DOMAIN_OPTIONAL macro is required.
#endif

#if PXFI_DOMAIN_MAIN
#define PXFI_DOMAIN_LABEL "main"
#define PXFI_CASE_PREFIX 'M'
#elif PXFI_DOMAIN_APP_GROUP
#define PXFI_DOMAIN_LABEL "app-group"
#define PXFI_CASE_PREFIX 'G'
#else
#define PXFI_DOMAIN_LABEL "optional"
#define PXFI_CASE_PREFIX 'O'
#endif

#define PXFI_MAX_DESCRIPTORS 4096
#define PXFI_MAX_DIRECTORIES 256
#define PXFI_MAX_REGISTERED_PATHS 8
#define PXFI_EVENT_LIMIT 64
#define PXFI_PRIMITIVE_LIMIT 32
#define PXFI_PATH_CAPACITY 4096

#pragma mark - Test-only model implementations

static const void *PXFIStageWorkspaceKey = &PXFIStageWorkspaceKey;
static const void *PXFIStageDataKey = &PXFIStageDataKey;
static const void *PXFIStageEntryCountKey = &PXFIStageEntryCountKey;
static const void *PXFIStageRegularCountKey = &PXFIStageRegularCountKey;
static const void *PXFIStageDirectoryCountKey = &PXFIStageDirectoryCountKey;
static const void *PXFIStageRegularBytesKey = &PXFIStageRegularBytesKey;
static const void *PXFIStageTreeDigestKey = &PXFIStageTreeDigestKey;

@interface PXValidatedMainDataStage (PXFITestConstruction)
+ (instancetype)pxfi_stageWithWorkspaceRootPath:(NSString *)workspaceRootPath
                                       dataPath:(NSString *)dataPath
                                     entryCount:(NSUInteger)entryCount
                               regularFileCount:(NSUInteger)regularFileCount
                                 directoryCount:(NSUInteger)directoryCount
                               regularFileBytes:(unsigned long long)regularFileBytes
                                     treeSHA256:(NSString *)treeSHA256;
- (instancetype)pxfi_init;
@end

@implementation PXValidatedMainDataStage
- (NSString *)workspaceRootPath { return objc_getAssociatedObject(self, PXFIStageWorkspaceKey); }
- (NSString *)dataPath { return objc_getAssociatedObject(self, PXFIStageDataKey); }
- (NSUInteger)entryCount { return [objc_getAssociatedObject(self, PXFIStageEntryCountKey) unsignedIntegerValue]; }
- (NSUInteger)regularFileCount { return [objc_getAssociatedObject(self, PXFIStageRegularCountKey) unsignedIntegerValue]; }
- (NSUInteger)directoryCount { return [objc_getAssociatedObject(self, PXFIStageDirectoryCountKey) unsignedIntegerValue]; }
- (unsigned long long)regularFileBytes { return [objc_getAssociatedObject(self, PXFIStageRegularBytesKey) unsignedLongLongValue]; }
- (NSString *)treeSHA256 { return objc_getAssociatedObject(self, PXFIStageTreeDigestKey); }
- (id)copyWithZone:(NSZone *)zone { (void)zone; return self; }
- (instancetype)pxfi_init { return [super init]; }
+ (instancetype)pxfi_stageWithWorkspaceRootPath:(NSString *)workspaceRootPath
                                       dataPath:(NSString *)dataPath
                                     entryCount:(NSUInteger)entryCount
                               regularFileCount:(NSUInteger)regularFileCount
                                 directoryCount:(NSUInteger)directoryCount
                               regularFileBytes:(unsigned long long)regularFileBytes
                                     treeSHA256:(NSString *)treeSHA256 {
    PXValidatedMainDataStage *stage = [[self alloc] pxfi_init];
    objc_setAssociatedObject(stage, PXFIStageWorkspaceKey, [workspaceRootPath copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(stage, PXFIStageDataKey, [dataPath copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(stage, PXFIStageEntryCountKey, @(entryCount), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(stage, PXFIStageRegularCountKey, @(regularFileCount), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(stage, PXFIStageDirectoryCountKey, @(directoryCount), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(stage, PXFIStageRegularBytesKey, @(regularFileBytes), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(stage, PXFIStageTreeDigestKey, [treeSHA256 copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
    return stage;
}
@end

#if PXFI_DOMAIN_OPTIONAL
static const void *PXFIFileStageWorkspaceKey = &PXFIFileStageWorkspaceKey;
static const void *PXFIFileStagePathKey = &PXFIFileStagePathKey;
static const void *PXFIFileStageBytesKey = &PXFIFileStageBytesKey;
static const void *PXFIFileStageDigestKey = &PXFIFileStageDigestKey;

@interface PXValidatedOptionalFileStage (PXFITestConstruction)
+ (instancetype)pxfi_stageWithWorkspaceRootPath:(NSString *)workspaceRootPath
                                       filePath:(NSString *)filePath
                                      byteCount:(unsigned long long)byteCount
                                         sha256:(NSString *)sha256;
- (instancetype)pxfi_init;
@end

@implementation PXValidatedOptionalFileStage
- (NSString *)workspaceRootPath { return objc_getAssociatedObject(self, PXFIFileStageWorkspaceKey); }
- (NSString *)filePath { return objc_getAssociatedObject(self, PXFIFileStagePathKey); }
- (unsigned long long)byteCount { return [objc_getAssociatedObject(self, PXFIFileStageBytesKey) unsignedLongLongValue]; }
- (NSString *)sha256 { return objc_getAssociatedObject(self, PXFIFileStageDigestKey); }
- (id)copyWithZone:(NSZone *)zone { (void)zone; return self; }
- (instancetype)pxfi_init { return [super init]; }
+ (instancetype)pxfi_stageWithWorkspaceRootPath:(NSString *)workspaceRootPath
                                       filePath:(NSString *)filePath
                                      byteCount:(unsigned long long)byteCount
                                         sha256:(NSString *)sha256 {
    PXValidatedOptionalFileStage *stage = [[self alloc] pxfi_init];
    objc_setAssociatedObject(stage, PXFIFileStageWorkspaceKey, [workspaceRootPath copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(stage, PXFIFileStagePathKey, [filePath copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(stage, PXFIFileStageBytesKey, @(byteCount), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(stage, PXFIFileStageDigestKey, [sha256 copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
    return stage;
}
@end
#endif

#if PXFI_DOMAIN_APP_GROUP
static const void *PXFIGroupIdentifiersKey = &PXFIGroupIdentifiersKey;
static const void *PXFIContainerModelsKey = &PXFIContainerModelsKey;
static const void *PXFIGroupCanonicalPathKey = &PXFIGroupCanonicalPathKey;
static const void *PXFIPlanItemsKey = &PXFIPlanItemsKey;

@interface PXAppGroupRestoreTarget (PXFITestConstruction)
+ (instancetype)pxfi_targetWithGroupIdentifiers:(NSArray<NSString *> *)groupIdentifiers
                                containerModels:(NSArray<PXResolvedContainer *> *)containerModels
                                  canonicalPath:(NSString *)canonicalPath;
- (instancetype)pxfi_init;
@end

@implementation PXAppGroupRestoreTarget
- (NSArray<NSString *> *)groupIdentifiers { return objc_getAssociatedObject(self, PXFIGroupIdentifiersKey); }
- (NSArray<PXResolvedContainer *> *)containerModels { return objc_getAssociatedObject(self, PXFIContainerModelsKey); }
- (NSString *)canonicalPath { return objc_getAssociatedObject(self, PXFIGroupCanonicalPathKey); }
- (NSArray *)planItems { return objc_getAssociatedObject(self, PXFIPlanItemsKey); }
- (id)copyWithZone:(NSZone *)zone { (void)zone; return self; }
- (instancetype)pxfi_init { return [super init]; }
+ (instancetype)pxfi_targetWithGroupIdentifiers:(NSArray<NSString *> *)groupIdentifiers
                                containerModels:(NSArray<PXResolvedContainer *> *)containerModels
                                  canonicalPath:(NSString *)canonicalPath {
    PXAppGroupRestoreTarget *target = [[self alloc] pxfi_init];
    objc_setAssociatedObject(target, PXFIGroupIdentifiersKey, [groupIdentifiers copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(target, PXFIContainerModelsKey, [containerModels copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(target, PXFIGroupCanonicalPathKey, [canonicalPath copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(target, PXFIPlanItemsKey, @[], OBJC_ASSOCIATION_COPY_NONATOMIC);
    return target;
}
@end
#endif

#if PXFI_DOMAIN_MAIN || PXFI_DOMAIN_APP_GROUP
static NSUInteger PXFIValidatorInvocationCount = 0;
static NSUInteger PXFIRejectValidatorOnInvocation = 0;
static BOOL PXFIPathIsExpectedDestination(NSString *path);

static void PXFIConfigureFinalValidationRejection(void) {
    PXFIValidatorInvocationCount = 0;
    PXFIRejectValidatorOnInvocation = 2;
}

@implementation PXDestructivePathValidator
- (NSString *)validatedCanonicalPathForContainer:(PXResolvedContainer *)container error:(NSError **)error {
    if (error) *error = nil;
    PXFIValidatorInvocationCount++;
    BOOL injectedRejection = PXFIRejectValidatorOnInvocation != 0 &&
                             PXFIValidatorInvocationCount == PXFIRejectValidatorOnInvocation;
    NSString *path = container.containerPath;
    BOOL valid = !injectedRejection &&
                 [container isKindOfClass:[PXResolvedContainer class]] &&
                 [path isKindOfClass:[NSString class]] &&
                 path.isAbsolutePath &&
                 [path.lastPathComponent isEqualToString:container.containerUUID] &&
                 PXFIPathIsExpectedDestination(path);
    if (!valid) {
        if (error) {
            *error = [NSError errorWithDomain:@"PXFITestDestructiveValidatorErrorDomain"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey: @"The test destination was rejected."}];
        }
        return nil;
    }
    return path;
}
@end
#endif

#pragma mark - Fault model

typedef NS_ENUM(int, PXFIPrimitive) {
    PXFIPrimitiveNone = 0,
    PXFIPrimitiveOpen = 1,
    PXFIPrimitiveOpenAt = 2,
    PXFIPrimitiveClose = 3,
    PXFIPrimitiveDup = 4,
    PXFIPrimitiveFcntl = 5,
    PXFIPrimitiveFlock = 6,
    PXFIPrimitiveFstat = 7,
    PXFIPrimitiveFstatAt = 8,
    PXFIPrimitiveLstat = 9,
    PXFIPrimitiveFchmod = 10,
    PXFIPrimitiveLseek = 11,
    PXFIPrimitiveMkdirAt = 12,
    PXFIPrimitiveRenameAt = 13,
    PXFIPrimitiveUnlinkAt = 14,
    PXFIPrimitiveFsync = 15,
    PXFIPrimitiveWrite = 16,
    PXFIPrimitiveRead = 17,
    PXFIPrimitiveFdopendir = 18,
    PXFIPrimitiveReaddir = 19,
    PXFIPrimitiveClosedir = 20,
};

typedef NS_ENUM(int, PXFISemanticEvent) {
    PXFISemanticEventAny = 0,
    PXFISemanticEventPassThrough = 1,
    PXFISemanticEventTargetOpen = 2,
    PXFISemanticEventTargetLockOpen = 3,
    PXFISemanticEventStageOpen = 4,
    PXFISemanticEventAuthorityOpen = 5,
    PXFISemanticEventWorkspaceCreation = 6,
    PXFISemanticEventWorkspacePreparation = 7,
    PXFISemanticEventJournalTemporaryOpen = 8,
    PXFISemanticEventJournalTemporaryWrite = 9,
    PXFISemanticEventJournalTemporaryFsync = 10,
    PXFISemanticEventJournalTemporaryClose = 11,
    PXFISemanticEventJournalPublicationRename = 12,
    PXFISemanticEventJournalPublicationDirectoryFsync = 13,
    PXFISemanticEventTargetToOriginalMove = 14,
    PXFISemanticEventStageToTargetMove = 15,
    PXFISemanticEventTargetToNewMove = 16,
    PXFISemanticEventOriginalToTargetRestore = 17,
    PXFISemanticEventQuarantineDirectoryFsync = 18,
    PXFISemanticEventInstallDirectoryFsync = 19,
    PXFISemanticEventWorkspaceCleanupUnlink = 20,
    PXFISemanticEventWorkspaceDirectoryRemoval = 21,
    PXFISemanticEventReplacementOpen = 22,
    PXFISemanticEventReplacementRead = 23,
    PXFISemanticEventReplacementWrite = 24,
    PXFISemanticEventReplacementFsync = 25,
    PXFISemanticEventStageFstat = 26,
};

typedef NS_ENUM(int, PXFIFaultAction) {
    PXFIFaultActionPass = 0,
    PXFIFaultActionFailBefore = 1,
    PXFIFaultActionFailAfterClose = 2,
    PXFIFaultActionEINTRThenSuccess = 3,
    PXFIFaultActionMutateSuccessfulFstatDevice = 4,
    PXFIFaultActionCrashBefore = 5,
    PXFIFaultActionCrashAfterSuccess = 6,
};

typedef NS_ENUM(int, PXFIDescriptorRole) {
    PXFIDescriptorRoleNone = 0,
    PXFIDescriptorRoleGeneric = 1,
    PXFIDescriptorRoleTarget = 2,
    PXFIDescriptorRoleTargetLock = 3,
    PXFIDescriptorRoleStage = 4,
    PXFIDescriptorRoleAuthority = 5,
    PXFIDescriptorRoleWorkspace = 6,
    PXFIDescriptorRoleParticipantWorkspace = 7,
    PXFIDescriptorRoleLeaderWorkspace = 8,
    PXFIDescriptorRoleOriginal = 9,
    PXFIDescriptorRoleNew = 10,
    PXFIDescriptorRoleReplacement = 11,
    PXFIDescriptorRoleJournalTemporary = 12,
    PXFIDescriptorRoleJournalFinal = 13,
    PXFIDescriptorRoleReplacementFile = 14,
};

typedef struct {
    PXFIPrimitive primitive;
    PXFISemanticEvent event;
    unsigned occurrence;
    PXFIFaultAction action;
    int errorNumber;
    unsigned remainingEINTR;
    dev_t replacementDevice;
    bool engaged;
    bool consumed;
} PXFIRule;

typedef struct {
    bool active;
    PXFIDescriptorRole role;
    char path[PXFI_PATH_CAPACITY];
} PXFIDescriptorRecord;

typedef struct {
    bool active;
    DIR *directory;
    PXFIDescriptorRole role;
    char path[PXFI_PATH_CAPACITY];
} PXFIDirectoryRecord;

static pthread_mutex_t PXFIStateMutex = PTHREAD_MUTEX_INITIALIZER;
static PXFIRule PXFICurrentRule;
static PXFIRule PXFISecondaryRule;
static int PXFILastConfiguredErrno = EIO;
static dev_t PXFILastConfiguredDevice = 0;
static PXFIDescriptorRecord PXFIDescriptors[PXFI_MAX_DESCRIPTORS];
static PXFIDirectoryRecord PXFIDirectories[PXFI_MAX_DIRECTORIES];
static unsigned PXFIEventCounts[PXFI_PRIMITIVE_LIMIT][PXFI_EVENT_LIMIT];
static unsigned PXFIInjectedCount = 0;
static unsigned PXFIUnknownFcntlCount = 0;
static unsigned PXFIJournalPublicationCount = 0;
static unsigned PXFIDurableJournalPhase = 0;
static int PXFIPendingJournalDirectoryDescriptor = -1;
static PXFISemanticEvent PXFILastMoveEvent = PXFISemanticEventPassThrough;
static char PXFICaseRoot[PXFI_PATH_CAPACITY];
static char PXFITargetPaths[PXFI_MAX_REGISTERED_PATHS][PXFI_PATH_CAPACITY];
static unsigned PXFITargetPathCount = 0;
static unsigned PXFITargetOpenCounts[PXFI_MAX_REGISTERED_PATHS];
static char PXFIStagePaths[PXFI_MAX_REGISTERED_PATHS][PXFI_PATH_CAPACITY];
static unsigned PXFIStagePathCount = 0;
static char PXFIAuthorityPaths[PXFI_MAX_REGISTERED_PATHS][PXFI_PATH_CAPACITY];
static unsigned PXFIAuthorityPathCount = 0;
static NSString *PXFIExecutablePath = nil;

static void PXFICopyCString(char *destination, size_t capacity, const char *source) {
    if (!destination || capacity == 0) return;
    if (!source) source = "";
    snprintf(destination, capacity, "%s", source);
}

static BOOL PXFIStringHasPrefix(const char *value, const char *prefix) {
    if (!value || !prefix) return NO;
    size_t prefixLength = strlen(prefix);
    return strncmp(value, prefix, prefixLength) == 0;
}

static BOOL PXFIPathEquals(const char *left, const char *right) {
    return left && right && strcmp(left, right) == 0;
}

static BOOL PXFIPathIsWithin(const char *root, const char *path) {
    if (!root || !path || root[0] != '/' || path[0] != '/') return NO;
    size_t rootLength = strlen(root);
    if (strncmp(root, path, rootLength) != 0) return NO;
    return path[rootLength] == '\0' || path[rootLength] == '/';
}

#if PXFI_DOMAIN_MAIN || PXFI_DOMAIN_APP_GROUP
static BOOL PXFIPathIsExpectedDestination(NSString *path) {
    if (![path isKindOfClass:[NSString class]] || !path.isAbsolutePath) return NO;
    const char *rawPath = path.fileSystemRepresentation;
    for (unsigned index = 0; index < PXFITargetPathCount; index++) {
        if (PXFIPathEquals(rawPath, PXFITargetPaths[index])) return YES;
    }
    return NO;
}
#endif

static void PXFIResetState(void) {
    pthread_mutex_lock(&PXFIStateMutex);
    memset(&PXFICurrentRule, 0, sizeof(PXFICurrentRule));
    memset(&PXFISecondaryRule, 0, sizeof(PXFISecondaryRule));
    PXFILastConfiguredErrno = EIO;
    PXFILastConfiguredDevice = 0;
    memset(PXFIDescriptors, 0, sizeof(PXFIDescriptors));
    memset(PXFIDirectories, 0, sizeof(PXFIDirectories));
    memset(PXFIEventCounts, 0, sizeof(PXFIEventCounts));
    memset(PXFICaseRoot, 0, sizeof(PXFICaseRoot));
    memset(PXFITargetPaths, 0, sizeof(PXFITargetPaths));
    memset(PXFITargetOpenCounts, 0, sizeof(PXFITargetOpenCounts));
    memset(PXFIStagePaths, 0, sizeof(PXFIStagePaths));
    memset(PXFIAuthorityPaths, 0, sizeof(PXFIAuthorityPaths));
    PXFITargetPathCount = 0;
    PXFIStagePathCount = 0;
    PXFIAuthorityPathCount = 0;
    PXFIInjectedCount = 0;
    PXFIUnknownFcntlCount = 0;
    PXFIJournalPublicationCount = 0;
    PXFIDurableJournalPhase = 0;
    PXFIPendingJournalDirectoryDescriptor = -1;
    PXFILastMoveEvent = PXFISemanticEventPassThrough;
    pthread_mutex_unlock(&PXFIStateMutex);
#if PXFI_DOMAIN_MAIN || PXFI_DOMAIN_APP_GROUP
    PXFIValidatorInvocationCount = 0;
    PXFIRejectValidatorOnInvocation = 0;
#endif
}

static void PXFIRegisterCString(char storage[PXFI_MAX_REGISTERED_PATHS][PXFI_PATH_CAPACITY],
                                unsigned *count,
                                const char *path) {
    if (!count || *count >= PXFI_MAX_REGISTERED_PATHS || !path) return;
    PXFICopyCString(storage[*count], PXFI_PATH_CAPACITY, path);
    (*count)++;
}

static void PXFIConfigurePaths(NSString *root,
                               NSArray<NSString *> *targets,
                               NSArray<NSString *> *stages,
                               NSArray<NSString *> *authorities) {
    pthread_mutex_lock(&PXFIStateMutex);
    PXFICopyCString(PXFICaseRoot, sizeof(PXFICaseRoot), root.fileSystemRepresentation);
    for (NSString *path in targets) PXFIRegisterCString(PXFITargetPaths, &PXFITargetPathCount, path.fileSystemRepresentation);
    for (NSString *path in stages) PXFIRegisterCString(PXFIStagePaths, &PXFIStagePathCount, path.fileSystemRepresentation);
    for (NSString *path in authorities) PXFIRegisterCString(PXFIAuthorityPaths, &PXFIAuthorityPathCount, path.fileSystemRepresentation);
    pthread_mutex_unlock(&PXFIStateMutex);
}

static void PXFISetRule(PXFIRule *rule,
                        PXFIPrimitive primitive,
                        PXFISemanticEvent event,
                        unsigned occurrence,
                        PXFIFaultAction action,
                        int errorNumber,
                        unsigned eintrCount,
                        dev_t replacementDevice) {
    memset(rule, 0, sizeof(*rule));
    rule->primitive = primitive;
    rule->event = event;
    rule->occurrence = occurrence;
    rule->action = action;
    rule->errorNumber = errorNumber;
    rule->remainingEINTR = eintrCount;
    rule->replacementDevice = replacementDevice;
}

static void PXFIConfigureRule(PXFIPrimitive primitive,
                              PXFISemanticEvent event,
                              unsigned occurrence,
                              PXFIFaultAction action,
                              int errorNumber,
                              unsigned eintrCount,
                              dev_t replacementDevice) {
    pthread_mutex_lock(&PXFIStateMutex);
    PXFISetRule(&PXFICurrentRule, primitive, event, occurrence, action,
                errorNumber, eintrCount, replacementDevice);
    pthread_mutex_unlock(&PXFIStateMutex);
}

static void PXFIConfigureSecondaryRule(PXFIPrimitive primitive,
                                       PXFISemanticEvent event,
                                       unsigned occurrence,
                                       PXFIFaultAction action,
                                       int errorNumber,
                                       unsigned eintrCount,
                                       dev_t replacementDevice) {
    pthread_mutex_lock(&PXFIStateMutex);
    PXFISetRule(&PXFISecondaryRule, primitive, event, occurrence, action,
                errorNumber, eintrCount, replacementDevice);
    pthread_mutex_unlock(&PXFIStateMutex);
}

static unsigned PXFIEventCount(PXFIPrimitive primitive, PXFISemanticEvent event) {
    if (primitive <= 0 || primitive >= PXFI_PRIMITIVE_LIMIT || event < 0 || event >= PXFI_EVENT_LIMIT) return 0;
    pthread_mutex_lock(&PXFIStateMutex);
    unsigned value = PXFIEventCounts[primitive][event];
    pthread_mutex_unlock(&PXFIStateMutex);
    return value;
}

static unsigned PXFIInjectedFaultCount(void) {
    pthread_mutex_lock(&PXFIStateMutex);
    unsigned value = PXFIInjectedCount;
    pthread_mutex_unlock(&PXFIStateMutex);
    return value;
}

static PXFIFaultAction PXFISelectRuleActionLocked(PXFIRule *rule,
                                                   PXFIPrimitive primitive,
                                                   PXFISemanticEvent event,
                                                   unsigned count) {
    BOOL sameRule = !rule->consumed &&
                    rule->primitive == primitive &&
                    (rule->event == PXFISemanticEventAny || rule->event == event);
    if (!sameRule) return PXFIFaultActionPass;
    PXFIFaultAction action = PXFIFaultActionPass;
    if (rule->engaged && rule->action == PXFIFaultActionEINTRThenSuccess) {
        if (rule->remainingEINTR > 0) {
            rule->remainingEINTR--;
            PXFIInjectedCount++;
            action = PXFIFaultActionEINTRThenSuccess;
        } else {
            rule->consumed = true;
        }
    } else if (!rule->engaged && count == rule->occurrence) {
        rule->engaged = true;
        action = rule->action;
        if (action == PXFIFaultActionEINTRThenSuccess) {
            if (rule->remainingEINTR > 0) {
                rule->remainingEINTR--;
                PXFIInjectedCount++;
            } else {
                action = PXFIFaultActionPass;
                rule->consumed = true;
            }
        } else if (action != PXFIFaultActionPass) {
            PXFIInjectedCount++;
            rule->consumed = true;
        }
    }
    if (action != PXFIFaultActionPass) {
        PXFILastConfiguredErrno = rule->errorNumber ?: EIO;
        PXFILastConfiguredDevice = rule->replacementDevice;
    }
    return action;
}

static PXFIFaultAction PXFISelectAction(PXFIPrimitive primitive, PXFISemanticEvent event) {
    pthread_mutex_lock(&PXFIStateMutex);
    unsigned count = 0;
    if (primitive > 0 && primitive < PXFI_PRIMITIVE_LIMIT && event >= 0 && event < PXFI_EVENT_LIMIT) {
        PXFIEventCounts[primitive][event]++;
        count = PXFIEventCounts[primitive][event];
    }
    PXFIFaultAction action = PXFISelectRuleActionLocked(&PXFICurrentRule, primitive, event, count);
    if (action == PXFIFaultActionPass) {
        action = PXFISelectRuleActionLocked(&PXFISecondaryRule, primitive, event, count);
    }
    pthread_mutex_unlock(&PXFIStateMutex);
    return action;
}

static int PXFIConfiguredErrno(void) {
    pthread_mutex_lock(&PXFIStateMutex);
    int value = PXFILastConfiguredErrno ?: EIO;
    pthread_mutex_unlock(&PXFIStateMutex);
    return value;
}

static dev_t PXFIConfiguredDevice(void) {
    pthread_mutex_lock(&PXFIStateMutex);
    dev_t value = PXFILastConfiguredDevice;
    pthread_mutex_unlock(&PXFIStateMutex);
    return value;
}

static void PXFICrashNow(void) {
    kill(getpid(), SIGKILL);
    _exit(127);
}

static BOOL PXFIDescriptorIndexValid(int descriptor) {
    return descriptor >= 0 && descriptor < PXFI_MAX_DESCRIPTORS;
}

static void PXFISetDescriptorRecord(int descriptor, PXFIDescriptorRole role, const char *path) {
    if (!PXFIDescriptorIndexValid(descriptor)) return;
    pthread_mutex_lock(&PXFIStateMutex);
    PXFIDescriptors[descriptor].active = true;
    PXFIDescriptors[descriptor].role = role;
    PXFICopyCString(PXFIDescriptors[descriptor].path, sizeof(PXFIDescriptors[descriptor].path), path);
    pthread_mutex_unlock(&PXFIStateMutex);
}

static void PXFIRemoveDescriptorRecord(int descriptor) {
    if (!PXFIDescriptorIndexValid(descriptor)) return;
    pthread_mutex_lock(&PXFIStateMutex);
    memset(&PXFIDescriptors[descriptor], 0, sizeof(PXFIDescriptors[descriptor]));
    pthread_mutex_unlock(&PXFIStateMutex);
}

static PXFIDescriptorRole PXFIRoleForDescriptor(int descriptor) {
    if (!PXFIDescriptorIndexValid(descriptor)) return PXFIDescriptorRoleNone;
    pthread_mutex_lock(&PXFIStateMutex);
    PXFIDescriptorRole role = PXFIDescriptors[descriptor].active ? PXFIDescriptors[descriptor].role : PXFIDescriptorRoleNone;
    pthread_mutex_unlock(&PXFIStateMutex);
    return role;
}

static BOOL PXFIPathForDescriptor(int descriptor, char *pathOut, size_t capacity) {
    if (!PXFIDescriptorIndexValid(descriptor) || !pathOut || capacity == 0) return NO;
    pthread_mutex_lock(&PXFIStateMutex);
    BOOL active = PXFIDescriptors[descriptor].active;
    if (active) PXFICopyCString(pathOut, capacity, PXFIDescriptors[descriptor].path);
    pthread_mutex_unlock(&PXFIStateMutex);
    return active;
}

static void PXFIJoinPath(int directoryDescriptor, const char *name, char *pathOut, size_t capacity) {
    char parent[PXFI_PATH_CAPACITY] = {0};
    if (name && name[0] == '/') {
        PXFICopyCString(pathOut, capacity, name);
        return;
    }
    if (!PXFIPathForDescriptor(directoryDescriptor, parent, sizeof(parent))) {
        PXFICopyCString(pathOut, capacity, name);
        return;
    }
    snprintf(pathOut, capacity, "%s/%s", parent, name ?: "");
}

static BOOL PXFIIsWorkspaceName(const char *name) {
    return PXFIStringHasPrefix(name, ".weaponx-main-restore-") ||
           PXFIStringHasPrefix(name, ".weaponx-app-group-restore-") ||
           PXFIStringHasPrefix(name, ".weaponx-optional-restore-");
}

static BOOL PXFIIsJournalTemporaryName(const char *name) {
    return name && (!strcmp(name, "journal.tmp") || !strcmp(name, "batch.tmp") || !strcmp(name, "transaction.tmp"));
}

static BOOL PXFIIsJournalFinalName(const char *name) {
    return name && (!strcmp(name, "journal.plist") || !strcmp(name, "batch.plist") || !strcmp(name, "transaction.plist"));
}

static PXFIDescriptorRole PXFIClassifyAbsolutePath(const char *path, PXFISemanticEvent *eventOut) {
    for (unsigned index = 0; index < PXFITargetPathCount; index++) {
        if (PXFIPathEquals(path, PXFITargetPaths[index])) {
            unsigned count = PXFITargetOpenCounts[index]++;
            if (eventOut) *eventOut = count == 0 ? PXFISemanticEventTargetOpen : PXFISemanticEventTargetLockOpen;
            return count == 0 ? PXFIDescriptorRoleTarget : PXFIDescriptorRoleTargetLock;
        }
    }
    for (unsigned index = 0; index < PXFIStagePathCount; index++) {
        if (PXFIPathEquals(path, PXFIStagePaths[index])) {
            if (eventOut) *eventOut = PXFISemanticEventStageOpen;
            return PXFIDescriptorRoleStage;
        }
    }
    for (unsigned index = 0; index < PXFIAuthorityPathCount; index++) {
        if (PXFIPathEquals(path, PXFIAuthorityPaths[index])) {
            if (eventOut) *eventOut = PXFISemanticEventAuthorityOpen;
            return PXFIDescriptorRoleAuthority;
        }
    }
    if (eventOut) *eventOut = PXFISemanticEventPassThrough;
    return PXFIDescriptorRoleGeneric;
}

static PXFIDescriptorRole PXFIClassifyChild(PXFIDescriptorRole parentRole,
                                             const char *name,
                                             PXFISemanticEvent *eventOut) {
    if ((parentRole == PXFIDescriptorRoleTarget ||
         parentRole == PXFIDescriptorRoleTargetLock ||
         parentRole == PXFIDescriptorRoleAuthority) && PXFIIsWorkspaceName(name)) {
        if (eventOut) *eventOut = PXFISemanticEventWorkspaceCreation;
        return PXFIDescriptorRoleParticipantWorkspace;
    }
    if (parentRole == PXFIDescriptorRoleWorkspace ||
        parentRole == PXFIDescriptorRoleParticipantWorkspace ||
        parentRole == PXFIDescriptorRoleLeaderWorkspace) {
        if (!strcmp(name, "original")) return PXFIDescriptorRoleOriginal;
        if (!strcmp(name, "new")) return PXFIDescriptorRoleNew;
        if (!strcmp(name, "replacement")) {
            if (eventOut) *eventOut = PXFISemanticEventReplacementOpen;
            return PXFIDescriptorRoleReplacement;
        }
        if (PXFIIsJournalTemporaryName(name)) {
            if (eventOut) *eventOut = PXFISemanticEventJournalTemporaryOpen;
            return PXFIDescriptorRoleJournalTemporary;
        }
        if (PXFIIsJournalFinalName(name)) return PXFIDescriptorRoleJournalFinal;
    }
    if (parentRole == PXFIDescriptorRoleStage) return PXFIDescriptorRoleStage;
    if (parentRole == PXFIDescriptorRoleTarget || parentRole == PXFIDescriptorRoleTargetLock) return PXFIDescriptorRoleTarget;
    if (parentRole == PXFIDescriptorRoleAuthority) return PXFIDescriptorRoleAuthority;
    return PXFIDescriptorRoleGeneric;
}

static PXFISemanticEvent PXFIEventForDescriptorPrimitive(PXFIPrimitive primitive, int descriptor) {
    PXFIDescriptorRole role = PXFIRoleForDescriptor(descriptor);
    if (role == PXFIDescriptorRoleJournalTemporary) {
        if (primitive == PXFIPrimitiveWrite) return PXFISemanticEventJournalTemporaryWrite;
        if (primitive == PXFIPrimitiveFsync) return PXFISemanticEventJournalTemporaryFsync;
        if (primitive == PXFIPrimitiveClose) return PXFISemanticEventJournalTemporaryClose;
    }
    if (role == PXFIDescriptorRoleReplacementFile) {
        if (primitive == PXFIPrimitiveWrite) return PXFISemanticEventReplacementWrite;
        if (primitive == PXFIPrimitiveFsync) return PXFISemanticEventReplacementFsync;
    }
    if (role == PXFIDescriptorRoleStage && primitive == PXFIPrimitiveRead) return PXFISemanticEventReplacementRead;
    if (role == PXFIDescriptorRoleStage && primitive == PXFIPrimitiveFstat) return PXFISemanticEventStageFstat;
    if (primitive == PXFIPrimitiveFsync && descriptor == PXFIPendingJournalDirectoryDescriptor) {
        return PXFISemanticEventJournalPublicationDirectoryFsync;
    }
    if (primitive == PXFIPrimitiveFsync &&
        PXFILastMoveEvent == PXFISemanticEventPassThrough &&
        (role == PXFIDescriptorRoleWorkspace ||
         role == PXFIDescriptorRoleParticipantWorkspace ||
         role == PXFIDescriptorRoleLeaderWorkspace ||
         role == PXFIDescriptorRoleTarget ||
         role == PXFIDescriptorRoleAuthority)) {
        return PXFISemanticEventWorkspacePreparation;
    }
    if (primitive == PXFIPrimitiveFsync &&
        (PXFILastMoveEvent == PXFISemanticEventTargetToOriginalMove ||
         PXFILastMoveEvent == PXFISemanticEventOriginalToTargetRestore)) {
        return PXFISemanticEventQuarantineDirectoryFsync;
    }
    if (primitive == PXFIPrimitiveFsync &&
        (PXFILastMoveEvent == PXFISemanticEventStageToTargetMove ||
         PXFILastMoveEvent == PXFISemanticEventTargetToNewMove)) {
        return PXFISemanticEventInstallDirectoryFsync;
    }
    return PXFISemanticEventPassThrough;
}

static PXFISemanticEvent PXFIClassifyRename(int sourceDirectoryDescriptor,
                                             const char *sourcePath,
                                             int destinationDirectoryDescriptor,
                                             const char *destinationPath) {
    PXFIDescriptorRole sourceRole = PXFIRoleForDescriptor(sourceDirectoryDescriptor);
    PXFIDescriptorRole destinationRole = PXFIRoleForDescriptor(destinationDirectoryDescriptor);
    BOOL sourceWorkspace = sourceRole == PXFIDescriptorRoleWorkspace ||
                           sourceRole == PXFIDescriptorRoleParticipantWorkspace ||
                           sourceRole == PXFIDescriptorRoleLeaderWorkspace;
    BOOL destinationWorkspace = destinationRole == PXFIDescriptorRoleWorkspace ||
                                destinationRole == PXFIDescriptorRoleParticipantWorkspace ||
                                destinationRole == PXFIDescriptorRoleLeaderWorkspace;
    BOOL sourceAuthority = sourceRole == PXFIDescriptorRoleTarget ||
                           sourceRole == PXFIDescriptorRoleAuthority;
    BOOL destinationAuthority = destinationRole == PXFIDescriptorRoleTarget ||
                                destinationRole == PXFIDescriptorRoleAuthority;
    if (sourceWorkspace &&
        sourceDirectoryDescriptor == destinationDirectoryDescriptor &&
        PXFIIsJournalTemporaryName(sourcePath) && PXFIIsJournalFinalName(destinationPath)) {
        return PXFISemanticEventJournalPublicationRename;
    }
    if (sourceAuthority &&
        (destinationRole == PXFIDescriptorRoleOriginal ||
         (destinationWorkspace && destinationPath && strcmp(destinationPath, "original") == 0))) {
        return PXFISemanticEventTargetToOriginalMove;
    }
    if ((sourceRole == PXFIDescriptorRoleStage ||
         sourceRole == PXFIDescriptorRoleReplacement ||
         sourceRole == PXFIDescriptorRoleReplacementFile ||
         (sourceWorkspace && sourcePath && strcmp(sourcePath, "replacement") == 0)) &&
        destinationAuthority) {
        return PXFISemanticEventStageToTargetMove;
    }
    if (sourceAuthority &&
        (destinationRole == PXFIDescriptorRoleNew ||
         (destinationWorkspace && destinationPath && strcmp(destinationPath, "new") == 0))) {
        return PXFISemanticEventTargetToNewMove;
    }
    if ((sourceRole == PXFIDescriptorRoleOriginal ||
         (sourceWorkspace && sourcePath && strcmp(sourcePath, "original") == 0)) &&
        destinationAuthority) {
        return PXFISemanticEventOriginalToTargetRestore;
    }
    return PXFISemanticEventPassThrough;
}

#pragma mark - POSIX wrappers

static BOOL PXFIOpenNeedsMode(int flags) {
    return (flags & O_CREAT) != 0;
}

int PXFI_open(const char *path, int flags, ...) {
    mode_t mode = 0;
    BOOL needsMode = PXFIOpenNeedsMode(flags);
    if (needsMode) {
        va_list arguments;
        va_start(arguments, flags);
        mode = (mode_t)va_arg(arguments, int);
        va_end(arguments);
    }
    PXFISemanticEvent event = PXFISemanticEventPassThrough;
    PXFIDescriptorRole role;
    pthread_mutex_lock(&PXFIStateMutex);
    role = PXFIClassifyAbsolutePath(path, &event);
    pthread_mutex_unlock(&PXFIStateMutex);
    PXFIFaultAction action = PXFISelectAction(PXFIPrimitiveOpen, event);
    if (action == PXFIFaultActionCrashBefore) PXFICrashNow();
    if (action == PXFIFaultActionFailBefore || action == PXFIFaultActionEINTRThenSuccess) {
        errno = action == PXFIFaultActionEINTRThenSuccess ? EINTR : PXFIConfiguredErrno();
        return -1;
    }
    int result = needsMode ? open(path, flags, mode) : open(path, flags);
    if (result >= 0) PXFISetDescriptorRecord(result, role, path);
    if (action == PXFIFaultActionCrashAfterSuccess && result >= 0) PXFICrashNow();
    return result;
}

int PXFI_openat(int directoryDescriptor, const char *path, int flags, ...) {
    mode_t mode = 0;
    BOOL needsMode = PXFIOpenNeedsMode(flags);
    if (needsMode) {
        va_list arguments;
        va_start(arguments, flags);
        mode = (mode_t)va_arg(arguments, int);
        va_end(arguments);
    }
    PXFISemanticEvent event = PXFISemanticEventPassThrough;
    PXFIDescriptorRole parentRole = PXFIRoleForDescriptor(directoryDescriptor);
    PXFIDescriptorRole role = PXFIClassifyChild(parentRole, path, &event);
    if (role == PXFIDescriptorRoleReplacement) {
        if ((flags & O_CREAT) != 0) {
            role = PXFIDescriptorRoleReplacementFile;
            event = PXFISemanticEventReplacementOpen;
        } else {
            event = PXFISemanticEventPassThrough;
        }
    }
    char resolved[PXFI_PATH_CAPACITY] = {0};
    PXFIJoinPath(directoryDescriptor, path, resolved, sizeof(resolved));
    PXFIFaultAction action = PXFISelectAction(PXFIPrimitiveOpenAt, event);
    if (action == PXFIFaultActionCrashBefore) PXFICrashNow();
    if (action == PXFIFaultActionFailBefore || action == PXFIFaultActionEINTRThenSuccess) {
        errno = action == PXFIFaultActionEINTRThenSuccess ? EINTR : PXFIConfiguredErrno();
        return -1;
    }
    int result = needsMode ? openat(directoryDescriptor, path, flags, mode)
                           : openat(directoryDescriptor, path, flags);
    if (result >= 0) {
        PXFISetDescriptorRecord(result, role, resolved);
        if (role == PXFIDescriptorRoleJournalTemporary &&
            (parentRole == PXFIDescriptorRoleParticipantWorkspace || parentRole == PXFIDescriptorRoleWorkspace)) {
            if (PXFIDescriptorIndexValid(directoryDescriptor)) {
                pthread_mutex_lock(&PXFIStateMutex);
                PXFIDescriptors[directoryDescriptor].role = PXFIDescriptorRoleLeaderWorkspace;
                pthread_mutex_unlock(&PXFIStateMutex);
            }
        }
    }
    if (action == PXFIFaultActionCrashAfterSuccess && result >= 0) PXFICrashNow();
    return result;
}

int PXFI_close(int descriptor) {
    PXFISemanticEvent event = PXFIEventForDescriptorPrimitive(PXFIPrimitiveClose, descriptor);
    PXFIFaultAction action = PXFISelectAction(PXFIPrimitiveClose, event);
    if (action == PXFIFaultActionCrashBefore) PXFICrashNow();
    if (action == PXFIFaultActionFailBefore || action == PXFIFaultActionEINTRThenSuccess) {
        errno = action == PXFIFaultActionEINTRThenSuccess ? EINTR : PXFIConfiguredErrno();
        return -1;
    }
    int result = close(descriptor);
    PXFIRemoveDescriptorRecord(descriptor);
    if (action == PXFIFaultActionFailAfterClose) {
        errno = PXFIConfiguredErrno();
        return -1;
    }
    if (action == PXFIFaultActionCrashAfterSuccess && result == 0) PXFICrashNow();
    return result;
}

int PXFI_dup(int descriptor) {
    PXFIFaultAction action = PXFISelectAction(PXFIPrimitiveDup, PXFISemanticEventPassThrough);
    if (action == PXFIFaultActionCrashBefore) PXFICrashNow();
    if (action == PXFIFaultActionFailBefore || action == PXFIFaultActionEINTRThenSuccess) {
        errno = action == PXFIFaultActionEINTRThenSuccess ? EINTR : PXFIConfiguredErrno();
        return -1;
    }
    int result = dup(descriptor);
    if (result >= 0) {
        char path[PXFI_PATH_CAPACITY] = {0};
        PXFIPathForDescriptor(descriptor, path, sizeof(path));
        PXFISetDescriptorRecord(result, PXFIRoleForDescriptor(descriptor), path);
    }
    if (action == PXFIFaultActionCrashAfterSuccess && result >= 0) PXFICrashNow();
    return result;
}

int PXFI_fcntl(int descriptor, int command, ...) {
    BOOL hasIntegerArgument = command == F_SETFD || command == F_DUPFD;
#ifdef F_DUPFD_CLOEXEC
    hasIntegerArgument = hasIntegerArgument || command == F_DUPFD_CLOEXEC;
#endif
    BOOL hasNoArgument = command == F_GETFD;
    int argument = 0;
    if (hasIntegerArgument) {
        va_list arguments;
        va_start(arguments, command);
        argument = va_arg(arguments, int);
        va_end(arguments);
    }
    if (!hasIntegerArgument && !hasNoArgument) {
        pthread_mutex_lock(&PXFIStateMutex);
        PXFIUnknownFcntlCount++;
        pthread_mutex_unlock(&PXFIStateMutex);
        errno = EINVAL;
        return -1;
    }
    PXFIFaultAction action = PXFISelectAction(PXFIPrimitiveFcntl, PXFISemanticEventPassThrough);
    if (action == PXFIFaultActionCrashBefore) PXFICrashNow();
    if (action == PXFIFaultActionFailBefore || action == PXFIFaultActionEINTRThenSuccess) {
        errno = action == PXFIFaultActionEINTRThenSuccess ? EINTR : PXFIConfiguredErrno();
        return -1;
    }
    int result = hasIntegerArgument ? fcntl(descriptor, command, argument) : fcntl(descriptor, command);
    if (result >= 0 && (command == F_DUPFD
#ifdef F_DUPFD_CLOEXEC
        || command == F_DUPFD_CLOEXEC
#endif
        )) {
        char path[PXFI_PATH_CAPACITY] = {0};
        PXFIPathForDescriptor(descriptor, path, sizeof(path));
        PXFISetDescriptorRecord(result, PXFIRoleForDescriptor(descriptor), path);
    }
    if (action == PXFIFaultActionCrashAfterSuccess && result >= 0) PXFICrashNow();
    return result;
}

int PXFI_flock(int descriptor, int operation) {
    PXFIFaultAction action = PXFISelectAction(PXFIPrimitiveFlock, PXFISemanticEventPassThrough);
    if (action == PXFIFaultActionCrashBefore) PXFICrashNow();
    if (action == PXFIFaultActionFailBefore || action == PXFIFaultActionEINTRThenSuccess) {
        errno = action == PXFIFaultActionEINTRThenSuccess ? EINTR : PXFIConfiguredErrno();
        return -1;
    }
    int result = flock(descriptor, operation);
    if (action == PXFIFaultActionCrashAfterSuccess && result == 0) PXFICrashNow();
    return result;
}

int PXFI_fstat(int descriptor, struct stat *value) {
    PXFISemanticEvent event = PXFIEventForDescriptorPrimitive(PXFIPrimitiveFstat, descriptor);
    PXFIFaultAction action = PXFISelectAction(PXFIPrimitiveFstat, event);
    if (action == PXFIFaultActionCrashBefore) PXFICrashNow();
    if (action == PXFIFaultActionFailBefore || action == PXFIFaultActionEINTRThenSuccess) {
        errno = action == PXFIFaultActionEINTRThenSuccess ? EINTR : PXFIConfiguredErrno();
        return -1;
    }
    int result = fstat(descriptor, value);
    if (result == 0 && action == PXFIFaultActionMutateSuccessfulFstatDevice && value) {
        value->st_dev = PXFIConfiguredDevice();
    }
    if (action == PXFIFaultActionCrashAfterSuccess && result == 0) PXFICrashNow();
    return result;
}

int PXFI_fstatat(int directoryDescriptor, const char *path, struct stat *value, int flags) {
    PXFIFaultAction action = PXFISelectAction(PXFIPrimitiveFstatAt, PXFISemanticEventPassThrough);
    if (action == PXFIFaultActionCrashBefore) PXFICrashNow();
    if (action == PXFIFaultActionFailBefore || action == PXFIFaultActionEINTRThenSuccess) {
        errno = action == PXFIFaultActionEINTRThenSuccess ? EINTR : PXFIConfiguredErrno();
        return -1;
    }
    int result = fstatat(directoryDescriptor, path, value, flags);
    if (result == 0 && action == PXFIFaultActionMutateSuccessfulFstatDevice && value) value->st_dev = PXFIConfiguredDevice();
    if (action == PXFIFaultActionCrashAfterSuccess && result == 0) PXFICrashNow();
    return result;
}

int PXFI_lstat(const char *path, struct stat *value) {
    PXFIFaultAction action = PXFISelectAction(PXFIPrimitiveLstat, PXFISemanticEventPassThrough);
    if (action == PXFIFaultActionCrashBefore) PXFICrashNow();
    if (action == PXFIFaultActionFailBefore || action == PXFIFaultActionEINTRThenSuccess) {
        errno = action == PXFIFaultActionEINTRThenSuccess ? EINTR : PXFIConfiguredErrno();
        return -1;
    }
    int result = lstat(path, value);
    if (result == 0 && action == PXFIFaultActionMutateSuccessfulFstatDevice && value) value->st_dev = PXFIConfiguredDevice();
    if (action == PXFIFaultActionCrashAfterSuccess && result == 0) PXFICrashNow();
    return result;
}

int PXFI_fchmod(int descriptor, mode_t mode) {
    PXFIFaultAction action = PXFISelectAction(PXFIPrimitiveFchmod, PXFISemanticEventPassThrough);
    if (action == PXFIFaultActionCrashBefore) PXFICrashNow();
    if (action == PXFIFaultActionFailBefore || action == PXFIFaultActionEINTRThenSuccess) {
        errno = action == PXFIFaultActionEINTRThenSuccess ? EINTR : PXFIConfiguredErrno();
        return -1;
    }
    int result = fchmod(descriptor, mode);
    if (action == PXFIFaultActionCrashAfterSuccess && result == 0) PXFICrashNow();
    return result;
}

off_t PXFI_lseek(int descriptor, off_t offset, int whence) {
    PXFIFaultAction action = PXFISelectAction(PXFIPrimitiveLseek, PXFISemanticEventPassThrough);
    if (action == PXFIFaultActionCrashBefore) PXFICrashNow();
    if (action == PXFIFaultActionFailBefore || action == PXFIFaultActionEINTRThenSuccess) {
        errno = action == PXFIFaultActionEINTRThenSuccess ? EINTR : PXFIConfiguredErrno();
        return (off_t)-1;
    }
    off_t result = lseek(descriptor, offset, whence);
    if (action == PXFIFaultActionCrashAfterSuccess && result >= 0) PXFICrashNow();
    return result;
}

int PXFI_mkdirat(int directoryDescriptor, const char *path, mode_t mode) {
    PXFIDescriptorRole parentRole = PXFIRoleForDescriptor(directoryDescriptor);
    PXFISemanticEvent event = ((parentRole == PXFIDescriptorRoleTarget || parentRole == PXFIDescriptorRoleAuthority) && PXFIIsWorkspaceName(path))
        ? PXFISemanticEventWorkspaceCreation : PXFISemanticEventWorkspacePreparation;
    PXFIFaultAction action = PXFISelectAction(PXFIPrimitiveMkdirAt, event);
    if (action == PXFIFaultActionCrashBefore) PXFICrashNow();
    if (action == PXFIFaultActionFailBefore || action == PXFIFaultActionEINTRThenSuccess) {
        errno = action == PXFIFaultActionEINTRThenSuccess ? EINTR : PXFIConfiguredErrno();
        return -1;
    }
    int result = mkdirat(directoryDescriptor, path, mode);
    if (action == PXFIFaultActionCrashAfterSuccess && result == 0) PXFICrashNow();
    return result;
}

int PXFI_renameat(int sourceDirectoryDescriptor,
                  const char *sourcePath,
                  int destinationDirectoryDescriptor,
                  const char *destinationPath) {
    PXFISemanticEvent event = PXFIClassifyRename(sourceDirectoryDescriptor, sourcePath,
                                                  destinationDirectoryDescriptor, destinationPath);
    PXFIFaultAction action = PXFISelectAction(PXFIPrimitiveRenameAt, event);
    if (action == PXFIFaultActionCrashBefore) PXFICrashNow();
    if (action == PXFIFaultActionFailBefore || action == PXFIFaultActionEINTRThenSuccess) {
        errno = action == PXFIFaultActionEINTRThenSuccess ? EINTR : PXFIConfiguredErrno();
        return -1;
    }
    int result = renameat(sourceDirectoryDescriptor, sourcePath,
                          destinationDirectoryDescriptor, destinationPath);
    if (result == 0) {
        pthread_mutex_lock(&PXFIStateMutex);
        if (event == PXFISemanticEventJournalPublicationRename) {
            PXFIJournalPublicationCount++;
            PXFIPendingJournalDirectoryDescriptor = destinationDirectoryDescriptor;
        }
        if (event == PXFISemanticEventTargetToOriginalMove ||
            event == PXFISemanticEventStageToTargetMove ||
            event == PXFISemanticEventTargetToNewMove ||
            event == PXFISemanticEventOriginalToTargetRestore) {
            PXFILastMoveEvent = event;
        }
        pthread_mutex_unlock(&PXFIStateMutex);
    }
    if (action == PXFIFaultActionCrashAfterSuccess && result == 0) PXFICrashNow();
    return result;
}

int PXFI_unlinkat(int directoryDescriptor, const char *path, int flags) {
    PXFIDescriptorRole parentRole = PXFIRoleForDescriptor(directoryDescriptor);
    PXFISemanticEvent event = PXFISemanticEventPassThrough;
    if ((parentRole == PXFIDescriptorRoleWorkspace ||
         parentRole == PXFIDescriptorRoleParticipantWorkspace ||
         parentRole == PXFIDescriptorRoleLeaderWorkspace ||
         parentRole == PXFIDescriptorRoleOriginal ||
         parentRole == PXFIDescriptorRoleNew ||
         parentRole == PXFIDescriptorRoleReplacement ||
         parentRole == PXFIDescriptorRoleReplacementFile)) {
        event = PXFISemanticEventWorkspaceCleanupUnlink;
    } else if ((parentRole == PXFIDescriptorRoleTarget || parentRole == PXFIDescriptorRoleAuthority) &&
               (flags & AT_REMOVEDIR) && PXFIIsWorkspaceName(path)) {
        event = PXFISemanticEventWorkspaceDirectoryRemoval;
    }
    PXFIFaultAction action = PXFISelectAction(PXFIPrimitiveUnlinkAt, event);
    if (action == PXFIFaultActionCrashBefore) PXFICrashNow();
    if (action == PXFIFaultActionFailBefore || action == PXFIFaultActionEINTRThenSuccess) {
        errno = action == PXFIFaultActionEINTRThenSuccess ? EINTR : PXFIConfiguredErrno();
        return -1;
    }
    int result = unlinkat(directoryDescriptor, path, flags);
    if (action == PXFIFaultActionCrashAfterSuccess && result == 0) PXFICrashNow();
    return result;
}

int PXFI_fsync(int descriptor) {
    PXFISemanticEvent event = PXFIEventForDescriptorPrimitive(PXFIPrimitiveFsync, descriptor);
    PXFIFaultAction action = PXFISelectAction(PXFIPrimitiveFsync, event);
    if (action == PXFIFaultActionCrashBefore) PXFICrashNow();
    if (action == PXFIFaultActionFailBefore || action == PXFIFaultActionEINTRThenSuccess) {
        errno = action == PXFIFaultActionEINTRThenSuccess ? EINTR : PXFIConfiguredErrno();
        return -1;
    }
    int result = fsync(descriptor);
    if (result == 0 && event == PXFISemanticEventJournalPublicationDirectoryFsync) {
        pthread_mutex_lock(&PXFIStateMutex);
        PXFIDurableJournalPhase = PXFIJournalPublicationCount;
        PXFIPendingJournalDirectoryDescriptor = -1;
        pthread_mutex_unlock(&PXFIStateMutex);
    }
    if (action == PXFIFaultActionCrashAfterSuccess && result == 0) PXFICrashNow();
    return result;
}

ssize_t PXFI_write(int descriptor, const void *bytes, size_t length) {
    PXFISemanticEvent event = PXFIEventForDescriptorPrimitive(PXFIPrimitiveWrite, descriptor);
    PXFIFaultAction action = PXFISelectAction(PXFIPrimitiveWrite, event);
    if (action == PXFIFaultActionCrashBefore) PXFICrashNow();
    if (action == PXFIFaultActionFailBefore || action == PXFIFaultActionEINTRThenSuccess) {
        errno = action == PXFIFaultActionEINTRThenSuccess ? EINTR : PXFIConfiguredErrno();
        return -1;
    }
    ssize_t result = write(descriptor, bytes, length);
    if (action == PXFIFaultActionCrashAfterSuccess && result >= 0) PXFICrashNow();
    return result;
}

ssize_t PXFI_read(int descriptor, void *bytes, size_t length) {
    PXFISemanticEvent event = PXFIEventForDescriptorPrimitive(PXFIPrimitiveRead, descriptor);
    PXFIFaultAction action = PXFISelectAction(PXFIPrimitiveRead, event);
    if (action == PXFIFaultActionCrashBefore) PXFICrashNow();
    if (action == PXFIFaultActionFailBefore || action == PXFIFaultActionEINTRThenSuccess) {
        errno = action == PXFIFaultActionEINTRThenSuccess ? EINTR : PXFIConfiguredErrno();
        return -1;
    }
    ssize_t result = read(descriptor, bytes, length);
    if (action == PXFIFaultActionCrashAfterSuccess && result >= 0) PXFICrashNow();
    return result;
}

DIR *PXFI_fdopendir(int descriptor) {
    PXFIFaultAction action = PXFISelectAction(PXFIPrimitiveFdopendir, PXFISemanticEventPassThrough);
    if (action == PXFIFaultActionCrashBefore) PXFICrashNow();
    if (action == PXFIFaultActionFailBefore || action == PXFIFaultActionEINTRThenSuccess) {
        errno = action == PXFIFaultActionEINTRThenSuccess ? EINTR : PXFIConfiguredErrno();
        return NULL;
    }
    PXFIDescriptorRole role = PXFIRoleForDescriptor(descriptor);
    char path[PXFI_PATH_CAPACITY] = {0};
    PXFIPathForDescriptor(descriptor, path, sizeof(path));
    DIR *result = fdopendir(descriptor);
    if (result) {
        PXFIRemoveDescriptorRecord(descriptor);
        pthread_mutex_lock(&PXFIStateMutex);
        for (unsigned index = 0; index < PXFI_MAX_DIRECTORIES; index++) {
            if (!PXFIDirectories[index].active) {
                PXFIDirectories[index].active = true;
                PXFIDirectories[index].directory = result;
                PXFIDirectories[index].role = role;
                PXFICopyCString(PXFIDirectories[index].path, sizeof(PXFIDirectories[index].path), path);
                break;
            }
        }
        pthread_mutex_unlock(&PXFIStateMutex);
    }
    if (action == PXFIFaultActionCrashAfterSuccess && result) PXFICrashNow();
    return result;
}

struct dirent *PXFI_readdir(DIR *directory) {
    PXFIFaultAction action = PXFISelectAction(PXFIPrimitiveReaddir, PXFISemanticEventPassThrough);
    if (action == PXFIFaultActionCrashBefore) PXFICrashNow();
    if (action == PXFIFaultActionFailBefore || action == PXFIFaultActionEINTRThenSuccess) {
        errno = action == PXFIFaultActionEINTRThenSuccess ? EINTR : PXFIConfiguredErrno();
        return NULL;
    }
    struct dirent *result = readdir(directory);
    if (action == PXFIFaultActionCrashAfterSuccess && result) PXFICrashNow();
    return result;
}

int PXFI_closedir(DIR *directory) {
    PXFIFaultAction action = PXFISelectAction(PXFIPrimitiveClosedir, PXFISemanticEventPassThrough);
    if (action == PXFIFaultActionCrashBefore) PXFICrashNow();
    if (action == PXFIFaultActionFailBefore || action == PXFIFaultActionEINTRThenSuccess) {
        errno = action == PXFIFaultActionEINTRThenSuccess ? EINTR : PXFIConfiguredErrno();
        return -1;
    }
    int result = closedir(directory);
    pthread_mutex_lock(&PXFIStateMutex);
    for (unsigned index = 0; index < PXFI_MAX_DIRECTORIES; index++) {
        if (PXFIDirectories[index].active && PXFIDirectories[index].directory == directory) {
            memset(&PXFIDirectories[index], 0, sizeof(PXFIDirectories[index]));
            break;
        }
    }
    pthread_mutex_unlock(&PXFIStateMutex);
    if (action == PXFIFaultActionCrashAfterSuccess && result == 0) PXFICrashNow();
    return result;
}

#pragma mark - Common filesystem helpers

static NSString *PXFILowercaseSHA256(NSData *data) {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *value = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) [value appendFormat:@"%02x", digest[index]];
    return value;
}

static BOOL PXFIWriteFile(NSString *path, NSData *data, mode_t mode) {
    int descriptor = open(path.fileSystemRepresentation, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, mode);
    if (descriptor < 0) return NO;
    const unsigned char *cursor = data.bytes;
    size_t remaining = data.length;
    BOOL ok = YES;
    while (remaining > 0) {
        ssize_t amount = write(descriptor, cursor, remaining);
        if (amount < 0 && errno == EINTR) continue;
        if (amount <= 0) { ok = NO; break; }
        cursor += amount;
        remaining -= (size_t)amount;
    }
    if (fchmod(descriptor, mode) != 0) ok = NO;
    if (close(descriptor) != 0) ok = NO;
    return ok;
}

static BOOL PXFICreateDirectory(NSString *path, mode_t mode) {
    if (mkdir(path.fileSystemRepresentation, mode) != 0) return NO;
    return chmod(path.fileSystemRepresentation, mode) == 0;
}

static NSString *PXFINewTemporaryRoot(void) {
    NSString *template = [NSTemporaryDirectory() stringByAppendingPathComponent:@"pxfi-XXXXXXXX"];
    NSMutableData *bytes = [[template dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    [bytes appendBytes:"\0" length:1];
    char *buffer = bytes.mutableBytes;
    if (!mkdtemp(buffer)) return nil;
    NSString *root = [NSString stringWithUTF8String:buffer];
    if (chmod(root.fileSystemRepresentation, 0700) != 0) {
        [[NSFileManager defaultManager] removeItemAtPath:root error:nil];
        return nil;
    }
    return root;
}

static BOOL PXFIRemoveRoot(NSString *root) {
    if (!root || !root.isAbsolutePath) return NO;
    return [[NSFileManager defaultManager] removeItemAtPath:root error:nil];
}

static NSDictionary *PXFIStatRecord(NSString *path) {
    struct stat value;
    memset(&value, 0, sizeof(value));
    if (lstat(path.fileSystemRepresentation, &value) != 0) return nil;
    NSMutableDictionary *record = [@{
        @"mode": @((unsigned long long)value.st_mode),
        @"uid": @((unsigned long long)value.st_uid),
        @"gid": @((unsigned long long)value.st_gid),
        @"nlink": @((unsigned long long)value.st_nlink),
        @"device": @((unsigned long long)value.st_dev),
        @"inode": @((unsigned long long)value.st_ino),
        @"size": @((long long)value.st_size),
#if defined(__APPLE__)
        @"mtimeSec": @((long long)value.st_mtimespec.tv_sec),
        @"mtimeNSec": @((long long)value.st_mtimespec.tv_nsec),
        @"ctimeSec": @((long long)value.st_ctimespec.tv_sec),
        @"ctimeNSec": @((long long)value.st_ctimespec.tv_nsec),
#else
        @"mtimeSec": @((long long)value.st_mtim.tv_sec),
        @"mtimeNSec": @((long long)value.st_mtim.tv_nsec),
        @"ctimeSec": @((long long)value.st_ctim.tv_sec),
        @"ctimeNSec": @((long long)value.st_ctim.tv_nsec),
#endif
    } mutableCopy];
    if (S_ISREG(value.st_mode)) {
        NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
        if (!data) return nil;
        record[@"type"] = @"file";
        record[@"sha256"] = PXFILowercaseSHA256(data);
    } else if (S_ISDIR(value.st_mode)) {
        record[@"type"] = @"directory";
    } else {
        record[@"type"] = @"other";
    }
    return [record copy];
}

static NSDictionary *PXFISnapshot(NSString *root) {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [manager enumeratorAtPath:root];
    if (!enumerator) return nil;
    NSMutableArray<NSString *> *paths = [NSMutableArray arrayWithObject:@"."];
    for (id value in enumerator) {
        if (![value isKindOfClass:[NSString class]]) return nil;
        [paths addObject:value];
    }
    [paths sortUsingSelector:@selector(compare:)];
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionaryWithCapacity:paths.count];
    for (NSString *relative in paths) {
        NSString *absolute = [relative isEqualToString:@"."] ? root : [root stringByAppendingPathComponent:relative];
        NSDictionary *record = PXFIStatRecord(absolute);
        if (!record) return nil;
        snapshot[relative] = record;
    }
    return [snapshot copy];
}

static void PXFIHashUInt32(CC_SHA256_CTX *context, uint32_t value) {
    unsigned char bytes[4] = {
        (unsigned char)((value >> 24) & 0xff),
        (unsigned char)((value >> 16) & 0xff),
        (unsigned char)((value >> 8) & 0xff),
        (unsigned char)(value & 0xff)
    };
    CC_SHA256_Update(context, bytes, (CC_LONG)sizeof(bytes));
}

static void PXFIHashUInt64(CC_SHA256_CTX *context, uint64_t value) {
    unsigned char bytes[8] = {
        (unsigned char)((value >> 56) & 0xff),
        (unsigned char)((value >> 48) & 0xff),
        (unsigned char)((value >> 40) & 0xff),
        (unsigned char)((value >> 32) & 0xff),
        (unsigned char)((value >> 24) & 0xff),
        (unsigned char)((value >> 16) & 0xff),
        (unsigned char)((value >> 8) & 0xff),
        (unsigned char)(value & 0xff)
    };
    CC_SHA256_Update(context, bytes, (CC_LONG)sizeof(bytes));
}

static NSComparisonResult PXFICompareUTF8Names(NSString *left, NSString *right) {
    NSData *leftBytes = [left dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    NSData *rightBytes = [right dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    NSUInteger common = MIN(leftBytes.length, rightBytes.length);
    int comparison = common ? memcmp(leftBytes.bytes, rightBytes.bytes, common) : 0;
    if (comparison < 0) return NSOrderedAscending;
    if (comparison > 0) return NSOrderedDescending;
    if (leftBytes.length < rightBytes.length) return NSOrderedAscending;
    if (leftBytes.length > rightBytes.length) return NSOrderedDescending;
    return NSOrderedSame;
}

static BOOL PXFIDigestTreeDirectory(NSString *root,
                                    NSString *relative,
                                    CC_SHA256_CTX *context,
                                    NSUInteger *entryCount,
                                    NSUInteger *regularFileCount,
                                    NSUInteger *directoryCount,
                                    unsigned long long *regularFileBytes) {
    NSString *directory = relative.length ? [root stringByAppendingPathComponent:relative] : root;
    NSArray<NSString *> *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:nil];
    if (!names) return NO;
    names = [names sortedArrayUsingComparator:^NSComparisonResult(NSString *left, NSString *right) {
        return PXFICompareUTF8Names(left, right);
    }];
    for (NSString *name in names) {
        NSData *nameBytes = [name dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
        if (!nameBytes || nameBytes.length == 0 || [name containsString:@"/"] || [name containsString:@"\0"]) return NO;
        NSString *childRelative = relative.length ? [relative stringByAppendingPathComponent:name] : name;
        NSData *pathBytes = [childRelative dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
        if (!pathBytes || pathBytes.length > UINT32_MAX) return NO;
        NSString *absolute = [root stringByAppendingPathComponent:childRelative];
        struct stat value; memset(&value, 0, sizeof(value));
        if (lstat(absolute.fileSystemRepresentation, &value) != 0 || value.st_nlink != 1 ||
            (value.st_mode & (S_ISUID | S_ISGID)) != 0) return NO;
        unsigned char type = 0;
        uint64_t size = 0;
        if (S_ISDIR(value.st_mode)) {
            type = 'D';
            (*directoryCount)++;
        } else if (S_ISREG(value.st_mode) && value.st_size >= 0) {
            type = 'F';
            size = (uint64_t)value.st_size;
            (*regularFileCount)++;
            if (*regularFileBytes > ULLONG_MAX - size) return NO;
            *regularFileBytes += size;
        } else {
            return NO;
        }
        (*entryCount)++;
        CC_SHA256_Update(context, &type, 1);
        PXFIHashUInt32(context, (uint32_t)pathBytes.length);
        if (pathBytes.length) CC_SHA256_Update(context, pathBytes.bytes, (CC_LONG)pathBytes.length);
        PXFIHashUInt32(context, (uint32_t)(value.st_mode & 07777));
        PXFIHashUInt64(context, size);
        if (type == 'D') {
            if (!PXFIDigestTreeDirectory(root, childRelative, context, entryCount,
                                         regularFileCount, directoryCount, regularFileBytes)) return NO;
        } else {
            NSData *payload = [NSData dataWithContentsOfFile:absolute options:NSDataReadingMappedIfSafe error:nil];
            if (!payload || payload.length != size) return NO;
            if (payload.length) CC_SHA256_Update(context, payload.bytes, (CC_LONG)payload.length);
        }
    }
    return YES;
}

static NSDictionary *PXFITreeDescription(NSString *root) {
    struct stat rootStat; memset(&rootStat, 0, sizeof(rootStat));
    if (![root isKindOfClass:[NSString class]] || !root.isAbsolutePath ||
        lstat(root.fileSystemRepresentation, &rootStat) != 0 || !S_ISDIR(rootStat.st_mode)) return nil;
    NSUInteger entryCount = 0, regularFileCount = 0, directoryCount = 0;
    unsigned long long regularFileBytes = 0;
    CC_SHA256_CTX context; CC_SHA256_Init(&context);
    static const unsigned char prefix[] = "PXMainDataStageTreeV1";
    CC_SHA256_Update(&context, prefix, (CC_LONG)sizeof(prefix));
    if (!PXFIDigestTreeDirectory(root, @"", &context, &entryCount, &regularFileCount,
                                 &directoryCount, &regularFileBytes)) return nil;
    unsigned char digest[CC_SHA256_DIGEST_LENGTH]; CC_SHA256_Final(digest, &context);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) [hex appendFormat:@"%02x", digest[index]];
    return @{
        @"entryCount": @(entryCount),
        @"regularFileCount": @(regularFileCount),
        @"directoryCount": @(directoryCount),
        @"regularFileBytes": @(regularFileBytes),
        @"treeSHA256": [hex copy]
    };
}

static BOOL PXFITreeDigestFixedVectors(void) {
    NSString *root = PXFINewTemporaryRoot();
    if (!root) return NO;
    BOOL ok = YES;
    NSArray<NSDictionary *> *vectors = @[
        @{@"name": @"empty", @"digest": @"4781eb8ee86207d7309c365562cd9d60abba337c3a9957770fa1f57b18d55c17"},
        @{@"name": @"one", @"digest": @"218d4a891457dc2cfb0f41ba8e1a119346b214722d0b6e20ad81f289924d1b92"},
        @{@"name": @"dirfile", @"digest": @"c6b0d673ade04c481ab6ef3d48e02c3541890089e7e4dce67d739ebf74234ed0"},
        @{@"name": @"siblings", @"digest": @"03574541e489c2316a58e35574b7cd872953402f0ab9a48592b191ada312e8b7"}
    ];
    for (NSDictionary *vector in vectors) {
        NSString *path = [root stringByAppendingPathComponent:vector[@"name"]];
        ok = ok && PXFICreateDirectory(path, 0700);
        if ([vector[@"name"] isEqualToString:@"one"]) {
            ok = ok && PXFIWriteFile([path stringByAppendingPathComponent:@"a.txt"], [@"A" dataUsingEncoding:NSUTF8StringEncoding], 0600);
        } else if ([vector[@"name"] isEqualToString:@"dirfile"]) {
            NSString *directory = [path stringByAppendingPathComponent:@"d"];
            ok = ok && PXFICreateDirectory(directory, 0700) &&
                 PXFIWriteFile([directory stringByAppendingPathComponent:@"a.txt"], [@"A" dataUsingEncoding:NSUTF8StringEncoding], 0600);
        } else if ([vector[@"name"] isEqualToString:@"siblings"]) {
            ok = ok && PXFIWriteFile([path stringByAppendingPathComponent:@"b.txt"], [@"B" dataUsingEncoding:NSUTF8StringEncoding], 0600) &&
                 PXFIWriteFile([path stringByAppendingPathComponent:@"a.txt"], [@"A" dataUsingEncoding:NSUTF8StringEncoding], 0600);
        }
        NSDictionary *description = ok ? PXFITreeDescription(path) : nil;
        ok = ok && [description[@"treeSHA256"] isEqualToString:vector[@"digest"]];
    }
    PXFIRemoveRoot(root);
    return ok;
}

static BOOL PXFIOutputIsPrivate(NSString *text, NSString *root, NSArray<NSString *> *secrets) {
    if (![text isKindOfClass:[NSString class]]) return NO;
    if (root.length && [text containsString:root]) return NO;
    for (NSString *secret in secrets) if (secret.length && [text containsString:secret]) return NO;
    return YES;
}

#pragma mark - Common self-tests

static NSArray<NSString *> *PXFIOrderedCaseIDs(void) {
    NSMutableArray<NSString *> *values = [NSMutableArray arrayWithCapacity:30];
    for (NSUInteger index = 1; index <= 30; index++) {
        [values addObject:[NSString stringWithFormat:@"%c%03lu", PXFI_CASE_PREFIX, (unsigned long)index]];
    }
    return [values copy];
}

static void PXFIAddFailure(NSMutableArray<NSDictionary *> *failures,
                           NSString *caseID,
                           NSString *assertion,
                           NSString *message) {
    [failures addObject:@{
        @"case": caseID ?: @"<suite>",
        @"assertion": assertion ?: @"assertion",
        @"message": message ?: @"failure"
    }];
}

static NSArray<NSDictionary *> *PXFISortedFailures(NSArray<NSDictionary *> *failures) {
    return [failures sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        for (NSString *key in @[@"case", @"assertion", @"message"]) {
            NSComparisonResult result = [left[key] compare:right[key]];
            if (result != NSOrderedSame) return result;
        }
        return NSOrderedSame;
    }];
}

static int PXFICommonSelfTestChild(NSString *caseID) {
    PXFIResetState();
    if ([caseID isEqualToString:@"SELFTEST-KILL-BEFORE"]) {
        PXFIConfigureRule(PXFIPrimitiveOpen, PXFISemanticEventPassThrough, 1,
                          PXFIFaultActionCrashBefore, 0, 0, 0);
    } else if ([caseID isEqualToString:@"SELFTEST-KILL-AFTER"]) {
        PXFIConfigureRule(PXFIPrimitiveOpen, PXFISemanticEventPassThrough, 1,
                          PXFIFaultActionCrashAfterSuccess, 0, 0, 0);
    } else {
        return 2;
    }
    int descriptor = PXFI_open("/dev/null", O_RDONLY | O_CLOEXEC);
    if (descriptor >= 0) PXFI_close(descriptor);
    return 2;
}

static BOOL PXFISpawnAndWait(NSArray<NSString *> *arguments, int *statusOut) {
    NSMutableArray<NSData *> *storage = [NSMutableArray arrayWithCapacity:arguments.count + 2];
    NSMutableArray<NSValue *> *pointers = [NSMutableArray arrayWithCapacity:arguments.count + 2];
    NSArray<NSString *> *all = [@[PXFIExecutablePath] arrayByAddingObjectsFromArray:arguments];
    for (NSString *argument in all) {
        NSMutableData *data = [[argument dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
        [data appendBytes:"\0" length:1];
        [storage addObject:data];
        [pointers addObject:[NSValue valueWithPointer:data.mutableBytes]];
    }
    char **argv = calloc(pointers.count + 1, sizeof(char *));
    if (!argv) return NO;
    for (NSUInteger index = 0; index < pointers.count; index++) argv[index] = [pointers[index] pointerValue];
    pid_t child = 0;
    int spawnResult = posix_spawn(&child, PXFIExecutablePath.fileSystemRepresentation, NULL, NULL, argv, environ);
    free(argv);
    if (spawnResult != 0) return NO;
    int status = 0;
    pid_t waited;
    do { waited = waitpid(child, &status, 0); } while (waited < 0 && errno == EINTR);
    if (waited != child) return NO;
    if (statusOut) *statusOut = status;
    return YES;
}

static BOOL PXFIRunWrapperSelfTest(NSString *root, NSUInteger ordinal) {
    NSString *target = [root stringByAppendingPathComponent:@"target"];
    NSString *stage = [root stringByAppendingPathComponent:@"stage"];
    NSString *file = [root stringByAppendingPathComponent:@"value.bin"];
    NSString *workspace = [target stringByAppendingPathComponent:@".weaponx-main-restore-00000000-0000-0000-0000-000000000000"];
    NSData *payload = [@"payload" dataUsingEncoding:NSUTF8StringEncoding];
    if (!PXFICreateDirectory(target, 0700) || !PXFICreateDirectory(stage, 0700) || !PXFIWriteFile(file, payload, 0600)) return NO;
    PXFIResetState();
    PXFIConfigurePaths(root, @[target], @[stage], @[]);

    if (ordinal == 5) {
        int fd = PXFI_open(file.fileSystemRepresentation, O_RDONLY | O_CLOEXEC);
        BOOL ok = fd >= 0; if (fd >= 0) PXFI_close(fd); return ok;
    }
    if (ordinal == 6) {
        NSString *created = [root stringByAppendingPathComponent:@"created.bin"];
        int fd = PXFI_open(created.fileSystemRepresentation, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
        struct stat value; memset(&value, 0, sizeof(value));
        BOOL ok = fd >= 0 && fstat(fd, &value) == 0 && (value.st_mode & 0777) == 0600;
        if (fd >= 0) PXFI_close(fd); return ok;
    }
    int targetFD = PXFI_open(target.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (targetFD < 0) return NO;
    if (ordinal == 7) {
        int fd = PXFI_openat(targetFD, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        BOOL ok = fd >= 0; if (fd >= 0) PXFI_close(fd); PXFI_close(targetFD); return ok;
    }
    if (ordinal == 8) {
        int fd = PXFI_openat(targetFD, "created.bin", O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
        BOOL ok = fd >= 0; if (fd >= 0) PXFI_close(fd); PXFI_close(targetFD); return ok;
    }
    if (ordinal == 9) {
        int value = PXFI_fcntl(targetFD, F_GETFD); PXFI_close(targetFD); return value >= 0;
    }
    if (ordinal == 10) {
        int setResult = PXFI_fcntl(targetFD, F_SETFD, FD_CLOEXEC);
        int duplicate = PXFI_fcntl(targetFD, F_DUPFD, 0);
        BOOL duplicateRole = duplicate >= 0 &&
                             PXFIRoleForDescriptor(duplicate) == PXFIRoleForDescriptor(targetFD);
#ifdef F_DUPFD_CLOEXEC
        int closeExecDuplicate = PXFI_fcntl(targetFD, F_DUPFD_CLOEXEC, 0);
        BOOL closeExecValid = closeExecDuplicate >= 0 &&
                              (PXFI_fcntl(closeExecDuplicate, F_GETFD) & FD_CLOEXEC) != 0 &&
                              PXFIRoleForDescriptor(closeExecDuplicate) == PXFIRoleForDescriptor(targetFD);
        if (closeExecDuplicate >= 0) PXFI_close(closeExecDuplicate);
#else
        BOOL closeExecValid = YES;
#endif
        if (duplicate >= 0) PXFI_close(duplicate);
        PXFI_close(targetFD);
        return setResult == 0 && duplicateRole && closeExecValid;
    }
    if (ordinal == 11) {
        struct stat value; BOOL ok = PXFI_fstat(targetFD, &value) == 0 && S_ISDIR(value.st_mode); PXFI_close(targetFD); return ok;
    }
    if (ordinal == 12) {
        struct stat directValue; memset(&directValue, 0, sizeof(directValue));
        errno = 0; int directResult = fstat(-1, &directValue); int directError = errno;
        struct stat wrappedValue; memset(&wrappedValue, 0, sizeof(wrappedValue));
        errno = 0; int wrappedResult = PXFI_fstat(-1, &wrappedValue); int wrappedError = errno;
        PXFI_close(targetFD);
        return directResult == -1 && wrappedResult == directResult && wrappedError == directError;
    }
    if (ordinal == 13) {
        PXFIConfigureRule(PXFIPrimitiveFsync, PXFISemanticEventAny, 1, PXFIFaultActionFailBefore, EIO, 0, 0);
        BOOL ok = PXFI_fsync(targetFD) == -1 && errno == EIO; PXFI_close(targetFD); return ok;
    }
    if (ordinal == 14) {
        PXFIConfigureRule(PXFIPrimitiveClose, PXFISemanticEventAny, 1, PXFIFaultActionFailAfterClose, EIO, 0, 0);
        int result = PXFI_close(targetFD);
        int injectedError = errno;
        int verify = fcntl(targetFD, F_GETFD);
        int verifyError = errno;
        return result == -1 && injectedError == EIO && verify == -1 && verifyError == EBADF &&
               PXFIRoleForDescriptor(targetFD) == PXFIDescriptorRoleNone;
    }
    if (ordinal == 15 || ordinal == 16) {
        int pipeFDs[2]; if (pipe(pipeFDs) != 0) { PXFI_close(targetFD); return NO; }
        PXFISetDescriptorRecord(pipeFDs[0], PXFIDescriptorRoleStage, "pipe-stage");
        write(pipeFDs[1], "x", 1);
        unsigned amount = ordinal == 15 ? 1 : 3;
        PXFIConfigureRule(PXFIPrimitiveRead, PXFISemanticEventReplacementRead, 1, PXFIFaultActionEINTRThenSuccess, EINTR, amount, 0);
        char byte = 0; unsigned retries = 0; ssize_t result;
        do { result = PXFI_read(pipeFDs[0], &byte, 1); if (result < 0 && errno == EINTR) retries++; } while (result < 0 && errno == EINTR && retries < 8);
        close(pipeFDs[0]); close(pipeFDs[1]); PXFI_close(targetFD);
        return result == 1 && byte == 'x' && retries == amount;
    }
    if (ordinal == 17) {
        int stageFD = PXFI_open(stage.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        struct stat realValue; fstat(stageFD, &realValue);
        dev_t replacement = realValue.st_dev + 123;
        PXFIConfigureRule(PXFIPrimitiveFstat, PXFISemanticEventStageFstat, 1, PXFIFaultActionMutateSuccessfulFstatDevice, 0, 0, replacement);
        struct stat value; memset(&value, 0, sizeof(value));
        BOOL ok = PXFI_fstat(stageFD, &value) == 0 && value.st_dev == replacement;
        PXFI_close(stageFD); PXFI_close(targetFD); return ok;
    }
    if (ordinal == 18) {
        BOOL ok = PXFIRoleForDescriptor(targetFD) == PXFIDescriptorRoleTarget; PXFI_close(targetFD); return ok;
    }
    if (ordinal == 19) {
        mkdir(workspace.fileSystemRepresentation, 0700);
        int fd = PXFI_openat(targetFD, workspace.lastPathComponent.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        BOOL ok = fd >= 0 && PXFIRoleForDescriptor(fd) == PXFIDescriptorRoleParticipantWorkspace;
        if (fd >= 0) PXFI_close(fd); PXFI_close(targetFD); return ok;
    }
    if (ordinal == 20) {
        int duplicate = PXFI_dup(targetFD);
        BOOL ok = duplicate >= 0 && PXFIRoleForDescriptor(duplicate) == PXFIRoleForDescriptor(targetFD);
        if (duplicate >= 0) PXFI_close(duplicate); PXFI_close(targetFD); return ok;
    }
    if (ordinal == 21) {
        int descriptor = targetFD; PXFI_close(descriptor); return PXFIRoleForDescriptor(descriptor) == PXFIDescriptorRoleNone;
    }
    if (ordinal == 22 || ordinal == 23) {
        int duplicate = PXFI_dup(targetFD); DIR *directory = PXFI_fdopendir(duplicate);
        BOOL transferred = directory && PXFIRoleForDescriptor(duplicate) == PXFIDescriptorRoleNone;
        BOOL closed = directory && PXFI_closedir(directory) == 0;
        PXFI_close(targetFD); return transferred && closed;
    }
    if (ordinal == 24) {
        mkdir(workspace.fileSystemRepresentation, 0700);
        int workspaceFD = PXFI_openat(targetFD, workspace.lastPathComponent.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        if (workspaceFD < 0) { PXFI_close(targetFD); return NO; }
        for (unsigned phase = 1; phase <= 2; phase++) {
            int journalFD = PXFI_openat(workspaceFD, "journal.tmp", O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
            if (journalFD < 0) { PXFI_close(workspaceFD); PXFI_close(targetFD); return NO; }
            PXFI_write(journalFD, "x", 1); PXFI_fsync(journalFD); PXFI_close(journalFD);
            if (PXFI_renameat(workspaceFD, "journal.tmp", workspaceFD, "journal.plist") != 0 || PXFI_fsync(workspaceFD) != 0) {
                PXFI_close(workspaceFD); PXFI_close(targetFD); return NO;
            }
        }
        BOOL ok = PXFIJournalPublicationCount == 2 && PXFIDurableJournalPhase == 2;
        PXFI_close(workspaceFD); PXFI_close(targetFD); return ok;
    }
    if (ordinal == 25) {
        mkdir(workspace.fileSystemRepresentation, 0700);
        NSString *original = [workspace stringByAppendingPathComponent:@"original"];
        NSString *newPath = [workspace stringByAppendingPathComponent:@"new"];
        mkdir(original.fileSystemRepresentation, 0700); mkdir(newPath.fileSystemRepresentation, 0700);
        NSString *targetValue = [target stringByAppendingPathComponent:@"old"];
        NSString *stageValue = [stage stringByAppendingPathComponent:@"new"];
        PXFIWriteFile(targetValue, payload, 0600); PXFIWriteFile(stageValue, payload, 0600);
        int workspaceFD = PXFI_openat(targetFD, workspace.lastPathComponent.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        int originalFD = PXFI_openat(workspaceFD, "original", O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        int newFD = PXFI_openat(workspaceFD, "new", O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        int stageFD = PXFI_open(stage.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        BOOL ok = PXFI_renameat(targetFD, "old", originalFD, "old") == 0 &&
                  PXFI_renameat(stageFD, "new", targetFD, "new") == 0 &&
                  PXFI_renameat(targetFD, "new", newFD, "new") == 0 &&
                  PXFI_renameat(originalFD, "old", targetFD, "old") == 0 &&
                  PXFIEventCount(PXFIPrimitiveRenameAt, PXFISemanticEventTargetToOriginalMove) == 1 &&
                  PXFIEventCount(PXFIPrimitiveRenameAt, PXFISemanticEventStageToTargetMove) == 1 &&
                  PXFIEventCount(PXFIPrimitiveRenameAt, PXFISemanticEventTargetToNewMove) == 1 &&
                  PXFIEventCount(PXFIPrimitiveRenameAt, PXFISemanticEventOriginalToTargetRestore) == 1;
        PXFI_close(stageFD); PXFI_close(newFD); PXFI_close(originalFD); PXFI_close(workspaceFD); PXFI_close(targetFD); return ok;
    }
    if (ordinal == 26) {
        mkdir(workspace.fileSystemRepresentation, 0700);
        NSString *child = [workspace stringByAppendingPathComponent:@"journal.plist"];
        PXFIWriteFile(child, payload, 0600);
        int workspaceFD = PXFI_openat(targetFD, workspace.lastPathComponent.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        BOOL ok = PXFI_unlinkat(workspaceFD, "journal.plist", 0) == 0;
        PXFI_close(workspaceFD);
        ok = ok && PXFI_unlinkat(targetFD, workspace.lastPathComponent.fileSystemRepresentation, AT_REMOVEDIR) == 0 &&
             PXFIEventCount(PXFIPrimitiveUnlinkAt, PXFISemanticEventWorkspaceCleanupUnlink) == 1 &&
             PXFIEventCount(PXFIPrimitiveUnlinkAt, PXFISemanticEventWorkspaceDirectoryRemoval) == 1;
        PXFI_close(targetFD); return ok;
    }
    PXFI_close(targetFD);
    return NO;
}

static int PXFIRunSelfTests(BOOL emitSuccess) {
    NSMutableArray<NSDictionary *> *failures = [NSMutableArray array];
    NSString *root = PXFINewTemporaryRoot();
    if (!root) {
        fprintf(stderr, "transaction fault self-test [%s]: fixture setup failed\n", PXFI_DOMAIN_LABEL);
        return 2;
    }
    for (NSUInteger ordinal = 1; ordinal <= 32; ordinal++) {
        BOOL passed = NO;
        @autoreleasepool {
            if (ordinal == 1) {
                passed = strlen(PXFI_DOMAIN_LABEL) > 0 && (PXFI_CASE_PREFIX == 'M' || PXFI_CASE_PREFIX == 'G' || PXFI_CASE_PREFIX == 'O');
            } else if (ordinal == 2) {
                passed = PXFIOrderedCaseIDs().count == 30;
            } else if (ordinal == 3) {
                NSArray *ids = PXFIOrderedCaseIDs();
                passed = [ids.firstObject isEqualToString:[NSString stringWithFormat:@"%c001", PXFI_CASE_PREFIX]] &&
                         [ids.lastObject isEqualToString:[NSString stringWithFormat:@"%c030", PXFI_CASE_PREFIX]];
            } else if (ordinal == 4) {
                NSArray *ids = PXFIOrderedCaseIDs();
                passed = [NSSet setWithArray:ids].count == ids.count && [NSSet setWithArray:[ids arrayByAddingObject:ids.firstObject]].count != ids.count + 1;
            } else if (ordinal >= 5 && ordinal <= 26) {
                NSString *subroot = [root stringByAppendingPathComponent:[NSString stringWithFormat:@"self-%02lu", (unsigned long)ordinal]];
                passed = PXFICreateDirectory(subroot, 0700) && PXFIRunWrapperSelfTest(subroot, ordinal);
            } else if (ordinal == 27) {
                int beforeStatus = 0;
                int afterStatus = 0;
                passed = PXFISpawnAndWait(@[@"--child", @"SELFTEST-KILL-BEFORE", root], &beforeStatus) &&
                         WIFSIGNALED(beforeStatus) && WTERMSIG(beforeStatus) == SIGKILL &&
                         PXFISpawnAndWait(@[@"--child", @"SELFTEST-KILL-AFTER", root], &afterStatus) &&
                         WIFSIGNALED(afterStatus) && WTERMSIG(afterStatus) == SIGKILL;
            } else if (ordinal == 28) {
                int status = 0;
                passed = PXFISpawnAndWait(@[@"--recover", @"SELFTEST-OK", root], &status) && WIFEXITED(status) && WEXITSTATUS(status) == 0;
            } else if (ordinal == 29) {
                NSString *path = [root stringByAppendingPathComponent:@"snapshot"];
                passed = PXFICreateDirectory(path, 0700) && PXFIWriteFile([path stringByAppendingPathComponent:@"value"], [@"stable" dataUsingEncoding:NSUTF8StringEncoding], 0600);
                NSDictionary *first = passed ? PXFISnapshot(path) : nil;
                NSDictionary *second = passed ? PXFISnapshot(path) : nil;
                passed = first && [first isEqualToDictionary:second];
#if PXFI_DOMAIN_OPTIONAL
                passed = passed && PXFITreeDigestFixedVectors();
#endif
            } else if (ordinal == 30) {
                passed = PXFIPathIsWithin(root.fileSystemRepresentation, root.fileSystemRepresentation) &&
                         PXFIPathIsWithin(root.fileSystemRepresentation, [root stringByAppendingPathComponent:@"child"].fileSystemRepresentation) &&
                         !PXFIPathIsWithin(root.fileSystemRepresentation, NSTemporaryDirectory().fileSystemRepresentation);
            } else if (ordinal == 31) {
                passed = PXFIOutputIsPrivate(@"generic deterministic failure", root, @[@"00000000-0000-0000-0000-000000000000"]) &&
                         !PXFIOutputIsPrivate(root, root, @[]);
            } else if (ordinal == 32) {
                NSArray *sorted = PXFISortedFailures(@[
                    @{@"case": @"B", @"assertion": @"z", @"message": @"2"},
                    @{@"case": @"A", @"assertion": @"z", @"message": @"1"},
                    @{@"case": @"A", @"assertion": @"a", @"message": @"3"}
                ]);
                passed = [sorted[0][@"assertion"] isEqualToString:@"a"] && [sorted[2][@"case"] isEqualToString:@"B"];
            }
        }
        if (!passed) PXFIAddFailure(failures, [NSString stringWithFormat:@"S%02lu", (unsigned long)ordinal], @"self-test", @"common self-test failed");
    }
    PXFIRemoveRoot(root);
    if (failures.count) {
        for (NSDictionary *failure in PXFISortedFailures(failures)) {
            fprintf(stderr, "%s %s: %s\n",
                    [failure[@"case"] UTF8String],
                    [failure[@"assertion"] UTF8String],
                    [failure[@"message"] UTF8String]);
        }
        return 1;
    }
    if (emitSuccess) printf("transaction fault self-test [%s]: PASS (32/32)\n", PXFI_DOMAIN_LABEL);
    return 0;
}

#pragma mark - Transaction suites

static NSUInteger PXFITrackedDescriptorCount(void) {
    pthread_mutex_lock(&PXFIStateMutex);
    NSUInteger count = 0;
    for (NSUInteger index = 0; index < PXFI_MAX_DESCRIPTORS; index++) if (PXFIDescriptors[index].active) count++;
    pthread_mutex_unlock(&PXFIStateMutex);
    return count;
}

static NSUInteger PXFITrackedDirectoryCount(void) {
    pthread_mutex_lock(&PXFIStateMutex);
    NSUInteger count = 0;
    for (NSUInteger index = 0; index < PXFI_MAX_DIRECTORIES; index++) if (PXFIDirectories[index].active) count++;
    pthread_mutex_unlock(&PXFIStateMutex);
    return count;
}

static NSArray<NSString *> *PXFIWorkspacePaths(NSString *authorityPath) {
    NSArray *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:authorityPath error:nil];
    NSMutableArray *paths = [NSMutableArray array];
    for (NSString *name in names) {
        if ([name hasPrefix:@".weaponx-main-restore-"] ||
            [name hasPrefix:@".weaponx-app-group-restore-"] ||
            [name hasPrefix:@".weaponx-optional-restore-"]) {
            [paths addObject:[authorityPath stringByAppendingPathComponent:name]];
        }
    }
    [paths sortUsingSelector:@selector(compare:)];
    return [paths copy];
}

static NSString *PXFIJournalPhaseAtWorkspace(NSString *workspace) {
    for (NSString *name in @[@"journal.plist", @"batch.plist", @"transaction.plist"]) {
        NSString *path = [workspace stringByAppendingPathComponent:name];
        NSData *data = [NSData dataWithContentsOfFile:path options:0 error:nil];
        if (!data) continue;
        id object = [NSPropertyListSerialization propertyListWithData:data
                                                              options:NSPropertyListImmutable
                                                               format:NULL
                                                                error:nil];
        if ([object isKindOfClass:[NSDictionary class]] && [object[@"phase"] isKindOfClass:[NSString class]]) {
            return object[@"phase"];
        }
    }
    return nil;
}

static BOOL PXFIErrorMatches(NSError *error,
                             NSString *domain,
                             NSInteger code,
                             NSString *fieldKey,
                             NSString *field,
                             NSString *root,
                             NSArray<NSString *> *privateValues) {
    if (![error isKindOfClass:[NSError class]] ||
        ![error.domain isEqualToString:domain] ||
        error.code != code ||
        ![error.userInfo[fieldKey] isEqualToString:field] ||
        ![error.localizedDescription isKindOfClass:[NSString class]] ||
        error.localizedDescription.length == 0) return NO;
    NSSet *keys = [NSSet setWithArray:error.userInfo.allKeys];
    NSSet *expected = [NSSet setWithArray:@[NSLocalizedDescriptionKey, fieldKey]];
    if (![keys isEqualToSet:expected]) return NO;
    NSMutableString *publicText = [NSMutableString stringWithFormat:@"%@ %@", error.domain, error.localizedDescription];
    for (id value in error.userInfo.allValues) if ([value isKindOfClass:[NSString class]]) [publicText appendFormat:@" %@", value];
    return PXFIOutputIsPrivate(publicText, root, privateValues);
}

static BOOL PXFIAcquireAndReleaseRealLock(NSString *path) {
    int descriptor = open(path.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (descriptor < 0) return NO;
    BOOL result = flock(descriptor, LOCK_EX | LOCK_NB) == 0;
    if (result) flock(descriptor, LOCK_UN);
    close(descriptor);
    return result;
}

static NSDictionary<NSString *, NSData *> *PXFIFlatRegularFiles(NSString *directory) {
    NSArray *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:nil];
    if (!names) return nil;
    NSMutableDictionary *files = [NSMutableDictionary dictionary];
    for (NSString *name in names) {
        if ([name hasPrefix:@".weaponx-"]) continue;
        NSString *path = [directory stringByAppendingPathComponent:name];
        struct stat value; memset(&value, 0, sizeof(value));
        if (lstat(path.fileSystemRepresentation, &value) != 0 ||
            !S_ISREG(value.st_mode) || (value.st_mode & 0777) != 0600) return nil;
        NSData *data = [NSData dataWithContentsOfFile:path options:0 error:nil];
        if (!data) return nil;
        files[name] = data;
    }
    return [files copy];
}

#if PXFI_DOMAIN_MAIN

@interface PXFIMainFixture : NSObject
@property (nonatomic, copy) NSString *root;
@property (nonatomic, copy) NSString *target;
@property (nonatomic, copy) NSString *stage;
@property (nonatomic, strong) PXResolvedContainer *container;
@property (nonatomic, strong) PXValidatedMainDataStage *stageModel;
@end
@implementation PXFIMainFixture @end

static NSString * const PXFIMainUUID = @"11111111-1111-1111-1111-111111111111";

static NSData *PXFIMainBytes(NSString *value) {
    return [value dataUsingEncoding:NSUTF8StringEncoding];
}

static PXFIMainFixture *PXFIMainFixtureAtRoot(NSString *root, BOOL create) {
    if (![root isKindOfClass:[NSString class]] || !root.isAbsolutePath) return nil;
    PXFIMainFixture *fixture = [[PXFIMainFixture alloc] init];
    fixture.root = root;
    fixture.target = [root stringByAppendingPathComponent:PXFIMainUUID];
    fixture.stage = [root stringByAppendingPathComponent:@"stage"];
    if (create) {
        if (!PXFICreateDirectory(fixture.target, 0700) || !PXFICreateDirectory(fixture.stage, 0700) ||
            !PXFIWriteFile([fixture.target stringByAppendingPathComponent:@"old-a.txt"], PXFIMainBytes(@"main-old-a\n"), 0600) ||
            !PXFIWriteFile([fixture.target stringByAppendingPathComponent:@"old-b.txt"], PXFIMainBytes(@"main-old-b\n"), 0600) ||
            !PXFIWriteFile([fixture.stage stringByAppendingPathComponent:@"new-a.txt"], PXFIMainBytes(@"main-new-a\n"), 0600) ||
            !PXFIWriteFile([fixture.stage stringByAppendingPathComponent:@"new-b.txt"], PXFIMainBytes(@"main-new-b\n"), 0600)) return nil;
    }
    fixture.container = [[PXResolvedContainer alloc]
        initWithKind:PXResolvedContainerKindApplicationData
        root:PXResolvedContainerRootRootful
        requestedIdentifier:@"com.example.main"
        metadataIdentifier:@"com.example.main"
        containerUUID:PXFIMainUUID
        containerPath:fixture.target];
    fixture.stageModel = [PXValidatedMainDataStage
        pxfi_stageWithWorkspaceRootPath:root
        dataPath:fixture.stage
        entryCount:2
        regularFileCount:2
        directoryCount:0
        regularFileBytes:22
        treeSHA256:@"0000000000000000000000000000000000000000000000000000000000000000"];
    if (!fixture.container || !fixture.stageModel) return nil;
    return fixture;
}

static NSString *PXFIMainState(NSString *target) {
    NSDictionary *files = PXFIFlatRegularFiles(target);
    NSDictionary *original = @{
        @"old-a.txt": PXFIMainBytes(@"main-old-a\n"),
        @"old-b.txt": PXFIMainBytes(@"main-old-b\n")
    };
    NSDictionary *installed = @{
        @"new-a.txt": PXFIMainBytes(@"main-new-a\n"),
        @"new-b.txt": PXFIMainBytes(@"main-new-b\n")
    };
    if ([files isEqualToDictionary:original]) return @"ORIGINAL";
    if ([files isEqualToDictionary:installed]) return @"INSTALLED";
    return @"MIXED";
}

static BOOL PXFIMainConfigureCommitCase(NSString *caseID) {
    NSInteger number = [[caseID substringFromIndex:1] integerValue];
    switch (number) {
        case 5:
            PXFIConfigureRule(PXFIPrimitiveWrite, PXFISemanticEventJournalTemporaryWrite, 1,
                              PXFIFaultActionEINTRThenSuccess, EINTR, 1, 0); break;
        case 6:
            PXFIConfigureRule(PXFIPrimitiveOpenAt, PXFISemanticEventJournalTemporaryOpen, 1,
                              PXFIFaultActionFailBefore, ENOSPC, 0, 0); break;
        case 7:
            PXFIConfigureRule(PXFIPrimitiveWrite, PXFISemanticEventJournalTemporaryWrite, 1,
                              PXFIFaultActionFailBefore, ENOSPC, 0, 0); break;
        case 8:
            PXFIConfigureRule(PXFIPrimitiveFsync, PXFISemanticEventJournalTemporaryFsync, 1,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 9:
            PXFIConfigureRule(PXFIPrimitiveClose, PXFISemanticEventJournalTemporaryClose, 1,
                              PXFIFaultActionFailAfterClose, EIO, 0, 0); break;
        case 10:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventJournalPublicationRename, 1,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 11:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventTargetToOriginalMove, 1,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 12:
            PXFIConfigureRule(PXFIPrimitiveFsync, PXFISemanticEventQuarantineDirectoryFsync, 1,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 13:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventJournalPublicationRename, 2,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 14:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventStageToTargetMove, 1,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 15:
            PXFIConfigureRule(PXFIPrimitiveFsync, PXFISemanticEventInstallDirectoryFsync, 1,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 16:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventJournalPublicationRename, 3,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 17:
            PXFIConfigureFinalValidationRejection(); break;
        case 18:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventJournalPublicationRename, 4,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 19:
            PXFIConfigureFinalValidationRejection();
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventTargetToNewMove, 1,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 20:
            PXFIConfigureFinalValidationRejection();
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventOriginalToTargetRestore, 1,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 21:
            PXFIConfigureFinalValidationRejection();
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventJournalPublicationRename, 5,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 22:
            PXFIConfigureRule(PXFIPrimitiveUnlinkAt, PXFISemanticEventWorkspaceCleanupUnlink, 10,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        default: break;
    }
    return YES;
}

static NSDictionary *PXFIMainExpectedError(NSInteger number) {
    switch (number) {
        case 2: return @{@"code": @(PXMainDataRestoreTransactionErrorInvalidInput), @"field": @"$.transaction"};
        case 3: return @{@"code": @(PXMainDataRestoreTransactionErrorFilesystemInspectionFailed), @"field": @"$.destination"};
        case 4: return @{@"code": @(PXMainDataRestoreTransactionErrorCrossDeviceBoundary), @"field": @"$.stage"};
        case 6: case 7: case 8: case 9: case 10:
        case 13: case 16: case 18:
            return @{@"code": @(PXMainDataRestoreTransactionErrorJournalCreationFailed), @"field": @"$.journal"};
        case 11: case 12:
            return @{@"code": @(PXMainDataRestoreTransactionErrorQuarantineFailed), @"field": @"$.transaction.quarantine"};
        case 14: case 15:
            return @{@"code": @(PXMainDataRestoreTransactionErrorCommitFailed), @"field": @"$.transaction.commit"};
        case 17:
            return @{@"code": @(PXMainDataRestoreTransactionErrorFilesystemChanged), @"field": @"$.transaction.commit"};
        case 19:
            return @{@"code": @(PXMainDataRestoreTransactionErrorRollbackFailed), @"field": @"$.transaction.rollback.new"};
        case 20:
            return @{@"code": @(PXMainDataRestoreTransactionErrorRollbackFailed), @"field": @"$.transaction.rollback.original"};
        case 21:
            return @{@"code": @(PXMainDataRestoreTransactionErrorRollbackFailed), @"field": @"$.transaction.rollback"};
        default: return nil;
    }
}

static BOOL PXFIMainValidateNormalCase(NSString *caseID,
                                       PXFIMainFixture *fixture,
                                       PXMainDataRestoreTransaction *transaction,
                                       BOOL factoryWasNil,
                                       BOOL commitResult,
                                       NSError *error,
                                       NSError *cleanupWarning,
                                       NSMutableArray<NSDictionary *> *failures) {
    NSInteger number = [[caseID substringFromIndex:1] integerValue];
    NSString *state = PXFIMainState(fixture.target);
    NSUInteger workspaceCount = PXFIWorkspacePaths(fixture.target).count;
    NSArray *privateValues = @[fixture.target, fixture.stage, PXFIMainUUID,
                               @"main-old-a", @"main-old-b", @"main-new-a", @"main-new-b"];
    BOOL ok = YES;
#define PXFI_MAIN_ASSERT(condition, name, message) do { if (!(condition)) { PXFIAddFailure(failures, caseID, name, message); ok = NO; } } while (0)
    if (number == 3 || number == 4) {
        NSDictionary *expected = PXFIMainExpectedError(number);
        PXFI_MAIN_ASSERT(factoryWasNil, @"factory.nil", @"factory result differed");
        PXFI_MAIN_ASSERT(PXFIErrorMatches(error,
                                          PXMainDataRestoreTransactionErrorDomain,
                                          [expected[@"code"] integerValue],
                                          PXMainDataRestoreTransactionErrorFieldPathKey,
                                          expected[@"field"],
                                          fixture.root,
                                          privateValues), @"factory.error", @"factory error differed");
        PXFI_MAIN_ASSERT([state isEqualToString:@"ORIGINAL"], @"filesystem.original", @"factory failure mutated target");
        PXFI_MAIN_ASSERT(workspaceCount == 0, @"workspace.absent", @"factory failure left workspace");
        return ok;
    }
    PXFI_MAIN_ASSERT(!factoryWasNil && transaction != nil, @"factory.nonnull", @"transaction factory failed");
    if (!transaction) return NO;
    if (number == 1 || number == 5) {
        PXFI_MAIN_ASSERT(commitResult, @"commit.yes", @"clean commit failed");
        PXFI_MAIN_ASSERT(error == nil && cleanupWarning == nil, @"commit.errors", @"clean commit returned error");
        PXFI_MAIN_ASSERT(transaction.committed && !transaction.rollbackPerformed && !transaction.rollbackComplete,
                         @"public.state", @"clean public state differed");
        PXFI_MAIN_ASSERT([state isEqualToString:@"INSTALLED"], @"filesystem.installed", @"installed target differed");
        PXFI_MAIN_ASSERT(workspaceCount == 0, @"workspace.cleaned", @"clean commit retained workspace");
    } else if (number == 2) {
        NSDictionary *expected = PXFIMainExpectedError(number);
        PXFI_MAIN_ASSERT(!commitResult, @"second.no", @"second commit unexpectedly succeeded");
        PXFI_MAIN_ASSERT(PXFIErrorMatches(error, PXMainDataRestoreTransactionErrorDomain,
                                          [expected[@"code"] integerValue], PXMainDataRestoreTransactionErrorFieldPathKey,
                                          expected[@"field"], fixture.root, privateValues),
                         @"second.error", @"second commit error differed");
        PXFI_MAIN_ASSERT(transaction.committed && !transaction.rollbackPerformed,
                         @"second.state", @"second commit changed public state");
        PXFI_MAIN_ASSERT([state isEqualToString:@"INSTALLED"], @"second.filesystem", @"second commit changed target");
    } else if (number >= 6 && number <= 10) {
        NSDictionary *expected = PXFIMainExpectedError(number);
        PXFI_MAIN_ASSERT(!commitResult, @"commit.no", @"journal failure unexpectedly succeeded");
        PXFI_MAIN_ASSERT(PXFIErrorMatches(error, PXMainDataRestoreTransactionErrorDomain,
                                          [expected[@"code"] integerValue], PXMainDataRestoreTransactionErrorFieldPathKey,
                                          expected[@"field"], fixture.root, privateValues),
                         @"commit.error", @"journal failure error differed");
        PXFI_MAIN_ASSERT(!transaction.committed && !transaction.rollbackPerformed && !transaction.rollbackComplete,
                         @"public.state", @"pre-mutation failure entered rollback");
        PXFI_MAIN_ASSERT([state isEqualToString:@"ORIGINAL"], @"filesystem.original", @"pre-mutation failure changed target");
    } else if (number >= 11 && number <= 18) {
        NSDictionary *expected = PXFIMainExpectedError(number);
        PXFI_MAIN_ASSERT(!commitResult, @"commit.no", @"pre-commit failure unexpectedly succeeded");
        PXFI_MAIN_ASSERT(PXFIErrorMatches(error, PXMainDataRestoreTransactionErrorDomain,
                                          [expected[@"code"] integerValue], PXMainDataRestoreTransactionErrorFieldPathKey,
                                          expected[@"field"], fixture.root, privateValues),
                         @"commit.error", @"operation error differed");
        PXFI_MAIN_ASSERT(!transaction.committed && transaction.rollbackPerformed && transaction.rollbackComplete,
                         @"rollback.complete", @"rollback did not complete");
        PXFI_MAIN_ASSERT([state isEqualToString:@"ORIGINAL"], @"filesystem.original", @"rollback did not restore original target");
        PXFI_MAIN_ASSERT(workspaceCount == 0, @"workspace.cleaned", @"completed rollback retained workspace");
    } else if (number >= 19 && number <= 21) {
        NSDictionary *expected = PXFIMainExpectedError(number);
        PXFI_MAIN_ASSERT(!commitResult, @"commit.no", @"rollback-failure case succeeded");
        PXFI_MAIN_ASSERT(PXFIErrorMatches(error, PXMainDataRestoreTransactionErrorDomain,
                                          [expected[@"code"] integerValue], PXMainDataRestoreTransactionErrorFieldPathKey,
                                          expected[@"field"], fixture.root, privateValues),
                         @"rollback.error", @"rollback error differed");
        PXFI_MAIN_ASSERT(!transaction.committed && transaction.rollbackPerformed && !transaction.rollbackComplete,
                         @"rollback.incomplete", @"rollback failure was normalized into completion");
        PXFI_MAIN_ASSERT(workspaceCount == 1, @"rollback.evidence", @"rollback evidence was not retained");
        if (number == 21) {
            PXFI_MAIN_ASSERT([state isEqualToString:@"ORIGINAL"],
                             @"rollback.original-undurable", @"durable rollback decision failed after original state restoration");
        }
    } else if (number == 22) {
        PXFI_MAIN_ASSERT(commitResult && error == nil, @"commit.yes", @"cleanup warning changed commit result");
        PXFI_MAIN_ASSERT(PXFIErrorMatches(cleanupWarning, PXMainDataRestoreTransactionErrorDomain,
                                          PXMainDataRestoreTransactionErrorCleanupFailed,
                                          PXMainDataRestoreTransactionErrorFieldPathKey,
                                          @"$.transaction.cleanup", fixture.root, privateValues),
                         @"cleanup.warning", @"cleanup warning differed");
        PXFI_MAIN_ASSERT(transaction.committed && !transaction.rollbackPerformed,
                         @"cleanup.state", @"cleanup warning changed committed state");
        PXFI_MAIN_ASSERT([state isEqualToString:@"INSTALLED"], @"cleanup.installed", @"cleanup warning damaged installed data");
        PXFI_MAIN_ASSERT(workspaceCount == 1, @"cleanup.evidence", @"cleanup warning did not retain confined evidence");
    }
#undef PXFI_MAIN_ASSERT
    return ok;
}

static BOOL PXFIRunOneMainNormalCase(NSString *caseID, NSMutableArray<NSDictionary *> *failures) {
    NSString *root = PXFINewTemporaryRoot();
    if (!root) { PXFIAddFailure(failures, caseID, @"fixture.root", @"fixture root creation failed"); return NO; }
    PXFIMainFixture *fixture = PXFIMainFixtureAtRoot(root, YES);
    if (!fixture) { PXFIRemoveRoot(root); PXFIAddFailure(failures, caseID, @"fixture.layout", @"fixture layout failed"); return NO; }
    PXFIResetState();
    PXFIConfigurePaths(root, @[fixture.target], @[fixture.stage], @[]);
    NSInteger number = [[caseID substringFromIndex:1] integerValue];
    int contentionDescriptor = -1;
    if (number == 3) {
        contentionDescriptor = open(fixture.target.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        if (contentionDescriptor < 0 || flock(contentionDescriptor, LOCK_EX | LOCK_NB) != 0) {
            if (contentionDescriptor >= 0) close(contentionDescriptor);
            PXFIRemoveRoot(root);
            PXFIAddFailure(failures, caseID, @"fixture.lock", @"real competing lock setup failed");
            return NO;
        }
    }
    if (number == 4) {
        struct stat stageStat; memset(&stageStat, 0, sizeof(stageStat)); lstat(fixture.stage.fileSystemRepresentation, &stageStat);
        PXFIConfigureRule(PXFIPrimitiveFstat, PXFISemanticEventStageFstat, 2,
                          PXFIFaultActionMutateSuccessfulFstatDevice, 0, 0, stageStat.st_dev + 1);
    }
    __block BOOL validated = NO;
    @autoreleasepool {
        NSError *factoryError = nil;
        PXMainDataRestoreTransaction *transaction =
            [PXMainDataRestoreTransaction transactionForContainer:fixture.container
                                                    canonicalPath:fixture.target
                                                   validatedStage:fixture.stageModel
                                                            error:&factoryError];
        if (contentionDescriptor >= 0) { flock(contentionDescriptor, LOCK_UN); close(contentionDescriptor); contentionDescriptor = -1; }
        if (!transaction) {
            validated = PXFIMainValidateNormalCase(caseID, fixture, nil, YES, NO, factoryError, nil, failures);
        } else {
            PXFIMainConfigureCommitCase(caseID);
            NSError *cleanupWarning = nil;
            NSError *commitError = nil;
            BOOL commitResult = [transaction commitWithCleanupWarning:&cleanupWarning error:&commitError];
            if (number == 2 && commitResult) {
                cleanupWarning = nil; commitError = nil;
                commitResult = [transaction commitWithCleanupWarning:&cleanupWarning error:&commitError];
            }
            validated = PXFIMainValidateNormalCase(caseID, fixture, transaction, NO, commitResult,
                                                    commitError, cleanupWarning, failures);
            transaction = nil;
        }
    }
    unsigned expectedInjected = (number == 1 || number == 2 || number == 3 || number == 17) ? 0 : 1;
    if (PXFIInjectedFaultCount() != expectedInjected) {
        PXFIAddFailure(failures, caseID, @"fault.consumed", @"main fault consumption count differed");
        validated = NO;
    }
    if (contentionDescriptor >= 0) { flock(contentionDescriptor, LOCK_UN); close(contentionDescriptor); }
    if (!PXFIAcquireAndReleaseRealLock(fixture.target)) {
        PXFIAddFailure(failures, caseID, @"hygiene.lock", @"transaction lock remained held");
        validated = NO;
    }
    if (PXFITrackedDescriptorCount() != 0 || PXFITrackedDirectoryCount() != 0) {
        PXFIAddFailure(failures, caseID, @"hygiene.descriptor", @"tracked descriptor or DIR role remained");
        validated = NO;
    }
    PXFIRemoveRoot(root);
    return validated;
}

static NSString *PXFIMainExpectedCrashPhase(NSString *caseID) {
    NSInteger number = [[caseID substringFromIndex:1] integerValue];
    switch (number) {
        case 23: case 24: return @"prepared";
        case 25: case 26: return @"quarantined";
        case 27: return @"installed";
        case 28: return @"committed";
        case 29: return @"rolling-back";
        case 30: return @"rolled-back";
        default: return nil;
    }
}

static void PXFIMainConfigureCrash(NSString *caseID) {
    NSInteger number = [[caseID substringFromIndex:1] integerValue];
    switch (number) {
        case 23:
            PXFIConfigureRule(PXFIPrimitiveFsync, PXFISemanticEventJournalPublicationDirectoryFsync, 1,
                              PXFIFaultActionCrashAfterSuccess, 0, 0, 0); break;
        case 24:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventTargetToOriginalMove, 1,
                              PXFIFaultActionCrashAfterSuccess, 0, 0, 0); break;
        case 25:
            PXFIConfigureRule(PXFIPrimitiveFsync, PXFISemanticEventJournalPublicationDirectoryFsync, 2,
                              PXFIFaultActionCrashAfterSuccess, 0, 0, 0); break;
        case 26:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventStageToTargetMove, 1,
                              PXFIFaultActionCrashAfterSuccess, 0, 0, 0); break;
        case 27:
            PXFIConfigureRule(PXFIPrimitiveFsync, PXFISemanticEventJournalPublicationDirectoryFsync, 3,
                              PXFIFaultActionCrashAfterSuccess, 0, 0, 0); break;
        case 28:
            PXFIConfigureRule(PXFIPrimitiveFsync, PXFISemanticEventJournalPublicationDirectoryFsync, 4,
                              PXFIFaultActionCrashAfterSuccess, 0, 0, 0); break;
        case 29:
            PXFIConfigureFinalValidationRejection();
            PXFIConfigureRule(PXFIPrimitiveFsync, PXFISemanticEventJournalPublicationDirectoryFsync, 4,
                              PXFIFaultActionCrashAfterSuccess, 0, 0, 0); break;
        case 30:
            PXFIConfigureFinalValidationRejection();
            PXFIConfigureRule(PXFIPrimitiveFsync, PXFISemanticEventJournalPublicationDirectoryFsync, 5,
                              PXFIFaultActionCrashAfterSuccess, 0, 0, 0); break;
        default: break;
    }
}

static int PXFIMainCrashChild(NSString *caseID, NSString *root) {
    PXFIMainFixture *fixture = PXFIMainFixtureAtRoot(root, NO);
    if (!fixture) return 2;
    PXFIResetState();
    PXFIConfigurePaths(root, @[fixture.target], @[fixture.stage], @[]);
    NSError *error = nil;
    PXMainDataRestoreTransaction *transaction =
        [PXMainDataRestoreTransaction transactionForContainer:fixture.container
                                                canonicalPath:fixture.target
                                               validatedStage:fixture.stageModel
                                                        error:&error];
    if (!transaction || error) return 2;
    PXFIMainConfigureCrash(caseID);
    NSError *warning = nil;
    BOOL result = [transaction commitWithCleanupWarning:&warning error:&error];
    (void)result; (void)warning; (void)error;
    return 2;
}

static int PXFIMainRecoveryChild(NSString *caseID, NSString *root) {
    PXFIMainFixture *fixture = PXFIMainFixtureAtRoot(root, NO);
    if (!fixture) return 2;
    PXFIResetState();
    PXFIConfigurePaths(root, @[fixture.target], @[fixture.stage], @[]);
    NSError *error = nil;
    PXMainDataRestoreTransaction *transaction =
        [PXMainDataRestoreTransaction transactionForContainer:fixture.container
                                                canonicalPath:fixture.target
                                               validatedStage:fixture.stageModel
                                                        error:&error];
    if (!transaction || error) return 2;
    NSDictionary *result = @{
        @"recovered": @(transaction.recoveredStaleTransactionCount),
        @"state": PXFIMainState(fixture.target),
        @"workspaceCount": @(PXFIWorkspacePaths(fixture.target).count)
    };
    transaction = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:result
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0
                                                               error:nil];
    NSString *path = [root stringByAppendingPathComponent:@"recovery-result.plist"];
    return data && PXFIWriteFile(path, data, 0600) ? 0 : 2;
}

static BOOL PXFIRunOneMainCrashCase(NSString *caseID, NSMutableArray<NSDictionary *> *failures) {
    NSString *root = PXFINewTemporaryRoot();
    if (!root) { PXFIAddFailure(failures, caseID, @"fixture.root", @"fixture root creation failed"); return NO; }
    PXFIMainFixture *fixture = PXFIMainFixtureAtRoot(root, YES);
    if (!fixture) { PXFIRemoveRoot(root); PXFIAddFailure(failures, caseID, @"fixture.layout", @"fixture layout failed"); return NO; }
    NSDictionary *initial = PXFISnapshot(root);
    int crashStatus = 0;
    BOOL ok = PXFISpawnAndWait(@[@"--child", caseID, root], &crashStatus) &&
              WIFSIGNALED(crashStatus) && WTERMSIG(crashStatus) == SIGKILL;
    if (!ok) PXFIAddFailure(failures, caseID, @"crash.sigkill", @"child did not terminate by SIGKILL");
    NSArray *workspaces = PXFIWorkspacePaths(fixture.target);
    NSString *phase = workspaces.count == 1 ? PXFIJournalPhaseAtWorkspace(workspaces.firstObject) : nil;
    if (![phase isEqualToString:PXFIMainExpectedCrashPhase(caseID)]) {
        PXFIAddFailure(failures, caseID, @"crash.phase", @"durable journal phase differed"); ok = NO;
    }
    NSDictionary *residue = PXFISnapshot(root);
    if (!residue || [residue isEqualToDictionary:initial]) {
        PXFIAddFailure(failures, caseID, @"crash.residue", @"crash residue did not preserve transaction evidence"); ok = NO;
    }
    int recoveryStatus = 0;
    if (!PXFISpawnAndWait(@[@"--recover", caseID, root], &recoveryStatus) ||
        !WIFEXITED(recoveryStatus) || WEXITSTATUS(recoveryStatus) != 0) {
        PXFIAddFailure(failures, caseID, @"recovery.process", @"fresh recovery process failed"); ok = NO;
    } else {
        NSString *resultPath = [root stringByAppendingPathComponent:@"recovery-result.plist"];
        NSData *data = [NSData dataWithContentsOfFile:resultPath options:0 error:nil];
        NSDictionary *result = data ? [NSPropertyListSerialization propertyListWithData:data
                                                                                 options:NSPropertyListImmutable
                                                                                  format:NULL
                                                                                   error:nil] : nil;
        NSString *expectedState = [caseID isEqualToString:@"M028"] ? @"INSTALLED" : @"ORIGINAL";
        if (![result isKindOfClass:[NSDictionary class]] ||
            [result[@"recovered"] unsignedIntegerValue] != 1 ||
            ![result[@"state"] isEqualToString:expectedState] ||
            [result[@"workspaceCount"] unsignedIntegerValue] != 0) {
            PXFIAddFailure(failures, caseID, @"recovery.result", @"stale recovery result differed"); ok = NO;
        }
        [[NSFileManager defaultManager] removeItemAtPath:resultPath error:nil];
    }
    if (!PXFIAcquireAndReleaseRealLock(fixture.target)) {
        PXFIAddFailure(failures, caseID, @"hygiene.lock", @"recovery left a lock held"); ok = NO;
    }
    PXFIRemoveRoot(root);
    return ok;
}

static int PXFIRunAllCases(void) {
    NSMutableArray<NSDictionary *> *failures = [NSMutableArray array];
    NSUInteger passed = 0;
    for (NSString *caseID in PXFIOrderedCaseIDs()) {
        BOOL ok = [[caseID substringFromIndex:1] integerValue] >= 23
            ? PXFIRunOneMainCrashCase(caseID, failures)
            : PXFIRunOneMainNormalCase(caseID, failures);
        if (ok) passed++;
    }
    if (failures.count || passed != 30) {
        for (NSDictionary *failure in PXFISortedFailures(failures)) {
            fprintf(stderr, "%s %s: %s\n", [failure[@"case"] UTF8String],
                    [failure[@"assertion"] UTF8String], [failure[@"message"] UTF8String]);
        }
        return 1;
    }
    printf("transaction fault cases [main]: PASS (30/30)\n");
    return 0;
}

static int PXFIInternalChild(NSString *caseID, NSString *root) {
    if (![root isKindOfClass:[NSString class]] || !root.isAbsolutePath) return 2;
    if ([caseID hasPrefix:@"SELFTEST-KILL-"]) return PXFICommonSelfTestChild(caseID);
    if ([caseID hasPrefix:@"M"] && [[caseID substringFromIndex:1] integerValue] >= 23) return PXFIMainCrashChild(caseID, root);
    return 2;
}

static int PXFIInternalRecover(NSString *caseID, NSString *root) {
    if (![root isKindOfClass:[NSString class]] || !root.isAbsolutePath) return 2;
    if ([caseID isEqualToString:@"SELFTEST-OK"]) return 0;
    if ([caseID hasPrefix:@"M"] && [[caseID substringFromIndex:1] integerValue] >= 23) return PXFIMainRecoveryChild(caseID, root);
    return 2;
}

#elif PXFI_DOMAIN_APP_GROUP

@interface PXFIAppGroupFixture : NSObject
@property (nonatomic, copy) NSString *root;
@property (nonatomic, copy) NSString *targetA;
@property (nonatomic, copy) NSString *targetB;
@property (nonatomic, copy) NSString *stageA;
@property (nonatomic, copy) NSString *stageB;
@property (nonatomic, copy) NSArray<PXAppGroupRestoreTarget *> *targets;
@property (nonatomic, copy) NSArray<PXValidatedMainDataStage *> *stages;
@end
@implementation PXFIAppGroupFixture @end

static NSString * const PXFIGroupUUIDA = @"22222222-2222-2222-2222-222222222222";
static NSString * const PXFIGroupUUIDB = @"33333333-3333-3333-3333-333333333333";

static NSData *PXFIGroupBytes(NSString *value) {
    return [value dataUsingEncoding:NSUTF8StringEncoding];
}

static PXFIAppGroupFixture *PXFIAppGroupFixtureAtRoot(NSString *root, BOOL create) {
    if (![root isKindOfClass:[NSString class]] || !root.isAbsolutePath) return nil;
    PXFIAppGroupFixture *fixture = [[PXFIAppGroupFixture alloc] init];
    fixture.root = root;
    fixture.targetA = [root stringByAppendingPathComponent:PXFIGroupUUIDA];
    fixture.targetB = [root stringByAppendingPathComponent:PXFIGroupUUIDB];
    fixture.stageA = [root stringByAppendingPathComponent:@"stage-A"];
    fixture.stageB = [root stringByAppendingPathComponent:@"stage-B"];
    if (create) {
        BOOL made = PXFICreateDirectory(fixture.targetA, 0700) &&
                    PXFICreateDirectory(fixture.targetB, 0700) &&
                    PXFICreateDirectory(fixture.stageA, 0700) &&
                    PXFICreateDirectory(fixture.stageB, 0700) &&
                    PXFIWriteFile([fixture.targetA stringByAppendingPathComponent:@"old-a-1.txt"], PXFIGroupBytes(@"group-old-a-1\n"), 0600) &&
                    PXFIWriteFile([fixture.targetA stringByAppendingPathComponent:@"old-a-2.txt"], PXFIGroupBytes(@"group-old-a-2\n"), 0600) &&
                    PXFIWriteFile([fixture.targetB stringByAppendingPathComponent:@"old-b-1.txt"], PXFIGroupBytes(@"group-old-b-1\n"), 0600) &&
                    PXFIWriteFile([fixture.targetB stringByAppendingPathComponent:@"old-b-2.txt"], PXFIGroupBytes(@"group-old-b-2\n"), 0600) &&
                    PXFIWriteFile([fixture.stageA stringByAppendingPathComponent:@"new-a-1.txt"], PXFIGroupBytes(@"group-new-a-1\n"), 0600) &&
                    PXFIWriteFile([fixture.stageA stringByAppendingPathComponent:@"new-a-2.txt"], PXFIGroupBytes(@"group-new-a-2\n"), 0600) &&
                    PXFIWriteFile([fixture.stageB stringByAppendingPathComponent:@"new-b-1.txt"], PXFIGroupBytes(@"group-new-b-1\n"), 0600) &&
                    PXFIWriteFile([fixture.stageB stringByAppendingPathComponent:@"new-b-2.txt"], PXFIGroupBytes(@"group-new-b-2\n"), 0600);
        if (!made) return nil;
    }
    PXResolvedContainer *containerA = [[PXResolvedContainer alloc]
        initWithKind:PXResolvedContainerKindAppGroup
        root:PXResolvedContainerRootRootful
        requestedIdentifier:@"group.com.example.a"
        metadataIdentifier:@"group.com.example.a"
        containerUUID:PXFIGroupUUIDA
        containerPath:fixture.targetA];
    PXResolvedContainer *containerB = [[PXResolvedContainer alloc]
        initWithKind:PXResolvedContainerKindAppGroup
        root:PXResolvedContainerRootRootful
        requestedIdentifier:@"group.com.example.b"
        metadataIdentifier:@"group.com.example.b"
        containerUUID:PXFIGroupUUIDB
        containerPath:fixture.targetB];
    PXAppGroupRestoreTarget *targetA = [PXAppGroupRestoreTarget
        pxfi_targetWithGroupIdentifiers:@[@"group.com.example.a"]
        containerModels:@[containerA]
        canonicalPath:fixture.targetA];
    PXAppGroupRestoreTarget *targetB = [PXAppGroupRestoreTarget
        pxfi_targetWithGroupIdentifiers:@[@"group.com.example.b"]
        containerModels:@[containerB]
        canonicalPath:fixture.targetB];
    PXValidatedMainDataStage *stageA = [PXValidatedMainDataStage
        pxfi_stageWithWorkspaceRootPath:root dataPath:fixture.stageA
        entryCount:2 regularFileCount:2 directoryCount:0 regularFileBytes:28
        treeSHA256:@"1111111111111111111111111111111111111111111111111111111111111111"];
    PXValidatedMainDataStage *stageB = [PXValidatedMainDataStage
        pxfi_stageWithWorkspaceRootPath:root dataPath:fixture.stageB
        entryCount:2 regularFileCount:2 directoryCount:0 regularFileBytes:28
        treeSHA256:@"2222222222222222222222222222222222222222222222222222222222222222"];
    if (!containerA || !containerB || !targetA || !targetB || !stageA || !stageB) return nil;
    fixture.targets = @[targetB, targetA];
    fixture.stages = @[stageB, stageA];
    return fixture;
}

static NSString *PXFIGroupTargetState(NSString *target, NSString *label) {
    NSDictionary *files = PXFIFlatRegularFiles(target);
    NSDictionary *original = [label isEqualToString:@"A"]
        ? @{@"old-a-1.txt": PXFIGroupBytes(@"group-old-a-1\n"), @"old-a-2.txt": PXFIGroupBytes(@"group-old-a-2\n")}
        : @{@"old-b-1.txt": PXFIGroupBytes(@"group-old-b-1\n"), @"old-b-2.txt": PXFIGroupBytes(@"group-old-b-2\n")};
    NSDictionary *installed = [label isEqualToString:@"A"]
        ? @{@"new-a-1.txt": PXFIGroupBytes(@"group-new-a-1\n"), @"new-a-2.txt": PXFIGroupBytes(@"group-new-a-2\n")}
        : @{@"new-b-1.txt": PXFIGroupBytes(@"group-new-b-1\n"), @"new-b-2.txt": PXFIGroupBytes(@"group-new-b-2\n")};
    if ([files isEqualToDictionary:original]) return @"ORIGINAL";
    if ([files isEqualToDictionary:installed]) return @"INSTALLED";
    return @"MIXED";
}

static BOOL PXFIGroupStateEquals(PXFIAppGroupFixture *fixture, NSString *state) {
    return [PXFIGroupTargetState(fixture.targetA, @"A") isEqualToString:state] &&
           [PXFIGroupTargetState(fixture.targetB, @"B") isEqualToString:state];
}

static NSArray<NSString *> *PXFIGroupAllWorkspaces(PXFIAppGroupFixture *fixture) {
    return [PXFIWorkspacePaths(fixture.targetA) arrayByAddingObjectsFromArray:PXFIWorkspacePaths(fixture.targetB)];
}

static NSString *PXFIGroupDurablePhase(PXFIAppGroupFixture *fixture) {
    NSMutableArray<NSString *> *phases = [NSMutableArray array];
    for (NSString *workspace in PXFIGroupAllWorkspaces(fixture)) {
        NSString *phase = PXFIJournalPhaseAtWorkspace(workspace);
        if (phase) [phases addObject:phase];
    }
    return phases.count == 1 ? phases.firstObject : nil;
}

static void PXFIGroupConfigureCommitCase(NSInteger number) {
    switch (number) {
        case 6:
            PXFIConfigureRule(PXFIPrimitiveWrite, PXFISemanticEventJournalTemporaryWrite, 1,
                              PXFIFaultActionEINTRThenSuccess, EINTR, 1, 0); break;
        case 7:
            PXFIConfigureRule(PXFIPrimitiveMkdirAt, PXFISemanticEventWorkspaceCreation, 2,
                              PXFIFaultActionFailBefore, ENOSPC, 0, 0); break;
        case 8:
            PXFIConfigureRule(PXFIPrimitiveFsync, PXFISemanticEventWorkspacePreparation, 1,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 9:
            PXFIConfigureRule(PXFIPrimitiveWrite, PXFISemanticEventJournalTemporaryWrite, 1,
                              PXFIFaultActionFailBefore, ENOSPC, 0, 0); break;
        case 10:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventJournalPublicationRename, 1,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 11:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventTargetToOriginalMove, 1,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 12:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventTargetToOriginalMove, 3,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 13:
            PXFIConfigureRule(PXFIPrimitiveFsync, PXFISemanticEventQuarantineDirectoryFsync, 1,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 14:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventJournalPublicationRename, 2,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 15:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventStageToTargetMove, 1,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 16:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventStageToTargetMove, 3,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 17:
            PXFIConfigureRule(PXFIPrimitiveFsync, PXFISemanticEventInstallDirectoryFsync, 1,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 18:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventJournalPublicationRename, 3,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 19:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventJournalPublicationRename, 4,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 20:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventJournalPublicationRename, 4,
                              PXFIFaultActionFailBefore, EIO, 0, 0);
            PXFIConfigureSecondaryRule(PXFIPrimitiveRenameAt, PXFISemanticEventTargetToNewMove, 1,
                                       PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 21:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventJournalPublicationRename, 4,
                              PXFIFaultActionFailBefore, EIO, 0, 0);
            PXFIConfigureSecondaryRule(PXFIPrimitiveRenameAt, PXFISemanticEventOriginalToTargetRestore, 1,
                                       PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 22:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventJournalPublicationRename, 4,
                              PXFIFaultActionFailBefore, EIO, 0, 0);
            PXFIConfigureSecondaryRule(PXFIPrimitiveRenameAt, PXFISemanticEventJournalPublicationRename, 6,
                                       PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 23:
            PXFIConfigureRule(PXFIPrimitiveUnlinkAt, PXFISemanticEventWorkspaceDirectoryRemoval, 1,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 24:
            PXFIConfigureRule(PXFIPrimitiveUnlinkAt, PXFISemanticEventWorkspaceDirectoryRemoval, 2,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        default: break;
    }
}

static NSDictionary *PXFIGroupExpectedError(NSInteger number) {
    if (number == 2) return @{@"code": @(PXAppGroupRestoreTransactionErrorInvalidInput), @"field": @"$"};
    if (number == 3 || number == 4) return @{@"code": @(PXAppGroupRestoreTransactionErrorLockFailed), @"field": @"$.locks"};
    if (number == 5) return @{@"code": @(PXAppGroupRestoreTransactionErrorCrossDeviceBoundary), @"field": @"$.stage"};
    if (number >= 7 && number <= 10) return @{@"code": @(PXAppGroupRestoreTransactionErrorJournalCreationFailed), @"field": @"$.journal"};
    if (number >= 11 && number <= 14) return @{@"code": @(PXAppGroupRestoreTransactionErrorQuarantineFailed), @"field": @"$.transaction.quarantine"};
    if (number >= 15 && number <= 19) return @{@"code": @(PXAppGroupRestoreTransactionErrorCommitFailed), @"field": @"$.transaction.commit"};
    if (number >= 20 && number <= 22) return @{@"code": @(PXAppGroupRestoreTransactionErrorRollbackFailed), @"field": @"$.transaction.rollback"};
    return nil;
}

static BOOL PXFIGroupValidateCase(NSString *caseID,
                                  PXFIAppGroupFixture *fixture,
                                  PXAppGroupRestoreTransaction *transaction,
                                  BOOL factoryNil,
                                  BOOL commitResult,
                                  NSError *error,
                                  NSError *cleanupWarning,
                                  NSMutableArray<NSDictionary *> *failures) {
    NSInteger number = [[caseID substringFromIndex:1] integerValue];
    NSArray *privateValues = @[fixture.targetA, fixture.targetB, fixture.stageA, fixture.stageB,
                               PXFIGroupUUIDA, PXFIGroupUUIDB, @"group-old", @"group-new"];
    BOOL ok = YES;
#define PXFI_GROUP_ASSERT(condition, name, message) do { if (!(condition)) { PXFIAddFailure(failures, caseID, name, message); ok = NO; } } while (0)
    if (number >= 3 && number <= 5) {
        NSDictionary *expected = PXFIGroupExpectedError(number);
        PXFI_GROUP_ASSERT(factoryNil, @"factory.nil", @"factory result differed");
        PXFI_GROUP_ASSERT(PXFIErrorMatches(error, PXAppGroupRestoreTransactionErrorDomain,
                                           [expected[@"code"] integerValue], PXAppGroupRestoreTransactionErrorFieldPathKey,
                                           expected[@"field"], fixture.root, privateValues),
                          @"factory.error", @"factory error differed");
        PXFI_GROUP_ASSERT(PXFIGroupStateEquals(fixture, @"ORIGINAL"), @"filesystem.original", @"factory failure mutated batch");
        PXFI_GROUP_ASSERT(PXFIGroupAllWorkspaces(fixture).count == 0, @"workspace.absent", @"factory failure retained workspace");
        return ok;
    }
    PXFI_GROUP_ASSERT(!factoryNil && transaction != nil, @"factory.nonnull", @"transaction factory failed");
    if (!transaction) return NO;
    if (number == 1 || number == 6) {
        PXFI_GROUP_ASSERT(commitResult && error == nil && cleanupWarning == nil, @"commit.yes", @"clean batch commit failed");
        PXFI_GROUP_ASSERT(transaction.committed && !transaction.rollbackPerformed && !transaction.rollbackComplete && transaction.targetCount == 2,
                          @"public.state", @"clean batch public state differed");
        PXFI_GROUP_ASSERT(PXFIGroupStateEquals(fixture, @"INSTALLED"), @"filesystem.installed", @"batch install differed");
        PXFI_GROUP_ASSERT(PXFIGroupAllWorkspaces(fixture).count == 0, @"workspace.cleaned", @"clean batch retained workspace");
    } else if (number == 2) {
        NSDictionary *expected = PXFIGroupExpectedError(number);
        PXFI_GROUP_ASSERT(!commitResult, @"second.no", @"second commit unexpectedly succeeded");
        PXFI_GROUP_ASSERT(PXFIErrorMatches(error, PXAppGroupRestoreTransactionErrorDomain,
                                           [expected[@"code"] integerValue], PXAppGroupRestoreTransactionErrorFieldPathKey,
                                           expected[@"field"], fixture.root, privateValues),
                          @"second.error", @"second commit error differed");
        PXFI_GROUP_ASSERT(transaction.committed && PXFIGroupStateEquals(fixture, @"INSTALLED"),
                          @"second.state", @"second commit changed installed batch");
    } else if (number >= 7 && number <= 10) {
        NSDictionary *expected = PXFIGroupExpectedError(number);
        PXFI_GROUP_ASSERT(!commitResult && PXFIErrorMatches(error, PXAppGroupRestoreTransactionErrorDomain,
                                                            [expected[@"code"] integerValue], PXAppGroupRestoreTransactionErrorFieldPathKey,
                                                            expected[@"field"], fixture.root, privateValues),
                          @"prepare.error", @"preparation error differed");
        PXFI_GROUP_ASSERT(!transaction.committed && !transaction.rollbackPerformed && !transaction.rollbackComplete,
                          @"prepare.state", @"preparation failure entered rollback");
        PXFI_GROUP_ASSERT(PXFIGroupStateEquals(fixture, @"ORIGINAL"), @"prepare.original", @"preparation failure changed targets");
    } else if (number >= 11 && number <= 19) {
        NSDictionary *expected = PXFIGroupExpectedError(number);
        PXFI_GROUP_ASSERT(!commitResult && PXFIErrorMatches(error, PXAppGroupRestoreTransactionErrorDomain,
                                                            [expected[@"code"] integerValue], PXAppGroupRestoreTransactionErrorFieldPathKey,
                                                            expected[@"field"], fixture.root, privateValues),
                          @"operation.error", @"whole-batch operation error differed");
        PXFI_GROUP_ASSERT(!transaction.committed && transaction.rollbackPerformed && transaction.rollbackComplete,
                          @"rollback.complete", @"whole-batch rollback did not complete");
        PXFI_GROUP_ASSERT(PXFIGroupStateEquals(fixture, @"ORIGINAL"), @"rollback.original", @"whole-batch rollback left mixed state");
        PXFI_GROUP_ASSERT(PXFIGroupAllWorkspaces(fixture).count == 0, @"rollback.cleaned", @"completed rollback retained workspace");
    } else if (number >= 20 && number <= 22) {
        NSDictionary *expected = PXFIGroupExpectedError(number);
        PXFI_GROUP_ASSERT(!commitResult && PXFIErrorMatches(error, PXAppGroupRestoreTransactionErrorDomain,
                                                            [expected[@"code"] integerValue], PXAppGroupRestoreTransactionErrorFieldPathKey,
                                                            expected[@"field"], fixture.root, privateValues),
                          @"rollback.error", @"rollback failure error differed");
        PXFI_GROUP_ASSERT(!transaction.committed && transaction.rollbackPerformed && !transaction.rollbackComplete,
                          @"rollback.incomplete", @"rollback failure was normalized into completion");
        PXFI_GROUP_ASSERT(PXFIGroupAllWorkspaces(fixture).count >= 1, @"rollback.evidence", @"rollback evidence was not retained");
        PXFI_GROUP_ASSERT(!(PXFIGroupStateEquals(fixture, @"INSTALLED")), @"rollback.notcommitted", @"rollback failure appeared committed");
        if (number == 22) {
            PXFI_GROUP_ASSERT(PXFIGroupStateEquals(fixture, @"ORIGINAL"),
                              @"rollback.original-undurable", @"rolled-back journal failure did not preserve original batch");
        }
    } else if (number == 23 || number == 24) {
        PXFI_GROUP_ASSERT(commitResult && error == nil, @"cleanup.commit", @"cleanup warning changed commit result");
        PXFI_GROUP_ASSERT(PXFIErrorMatches(cleanupWarning, PXAppGroupRestoreTransactionErrorDomain,
                                           PXAppGroupRestoreTransactionErrorCleanupFailed,
                                           PXAppGroupRestoreTransactionErrorFieldPathKey,
                                           @"$.transaction.cleanup", fixture.root, privateValues),
                          @"cleanup.warning", @"cleanup warning differed");
        PXFI_GROUP_ASSERT(transaction.committed && PXFIGroupStateEquals(fixture, @"INSTALLED"),
                          @"cleanup.installed", @"cleanup warning damaged batch");
        PXFI_GROUP_ASSERT(PXFIGroupAllWorkspaces(fixture).count >= 1, @"cleanup.evidence", @"cleanup evidence was not confined");
    }
#undef PXFI_GROUP_ASSERT
    return ok;
}

static BOOL PXFIRunOneGroupNormalCase(NSString *caseID, NSMutableArray<NSDictionary *> *failures) {
    NSString *root = PXFINewTemporaryRoot();
    if (!root) { PXFIAddFailure(failures, caseID, @"fixture.root", @"fixture root creation failed"); return NO; }
    PXFIAppGroupFixture *fixture = PXFIAppGroupFixtureAtRoot(root, YES);
    if (!fixture) { PXFIRemoveRoot(root); PXFIAddFailure(failures, caseID, @"fixture.layout", @"fixture layout failed"); return NO; }
    PXFIResetState();
    PXFIConfigurePaths(root, @[fixture.targetA, fixture.targetB], @[fixture.stageA, fixture.stageB], @[]);
    NSInteger number = [[caseID substringFromIndex:1] integerValue];
    int contentionDescriptor = -1;
    NSString *contentionPath = nil;
    if (number == 3 || number == 4) {
        contentionPath = number == 3 ? fixture.targetA : fixture.targetB;
        contentionDescriptor = open(contentionPath.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        if (contentionDescriptor < 0 || flock(contentionDescriptor, LOCK_EX | LOCK_NB) != 0) {
            if (contentionDescriptor >= 0) close(contentionDescriptor);
            PXFIRemoveRoot(root); PXFIAddFailure(failures, caseID, @"fixture.lock", @"real contention setup failed"); return NO;
        }
    }
    if (number == 5) {
        struct stat value; memset(&value, 0, sizeof(value)); lstat(fixture.stageB.fileSystemRepresentation, &value);
        PXFIConfigureRule(PXFIPrimitiveFstat, PXFISemanticEventStageFstat, 6,
                          PXFIFaultActionMutateSuccessfulFstatDevice, 0, 0, value.st_dev + 1);
    }
    __block BOOL validated = NO;
    @autoreleasepool {
        NSError *factoryError = nil;
        PXAppGroupRestoreTransaction *transaction =
            [PXAppGroupRestoreTransaction transactionForTargets:fixture.targets validatedStages:fixture.stages error:&factoryError];
        if (contentionDescriptor >= 0) { flock(contentionDescriptor, LOCK_UN); close(contentionDescriptor); contentionDescriptor = -1; }
        if (!transaction) {
            validated = PXFIGroupValidateCase(caseID, fixture, nil, YES, NO, factoryError, nil, failures);
        } else {
            PXFIGroupConfigureCommitCase(number);
            NSError *warning = nil; NSError *commitError = nil;
            BOOL result = [transaction commitWithCleanupWarning:&warning error:&commitError];
            if (number == 2 && result) { warning = nil; commitError = nil; result = [transaction commitWithCleanupWarning:&warning error:&commitError]; }
            validated = PXFIGroupValidateCase(caseID, fixture, transaction, NO, result, commitError, warning, failures);
            transaction = nil;
        }
    }
    unsigned expectedInjected = number <= 4 ? 0 : ((number >= 20 && number <= 22) ? 2 : 1);
    if (PXFIInjectedFaultCount() != expectedInjected) {
        PXFIAddFailure(failures, caseID, @"fault.consumed", @"App Group fault consumption count differed");
        validated = NO;
    }
    if (contentionDescriptor >= 0) { flock(contentionDescriptor, LOCK_UN); close(contentionDescriptor); }
    if (!PXFIAcquireAndReleaseRealLock(fixture.targetA) || !PXFIAcquireAndReleaseRealLock(fixture.targetB)) {
        PXFIAddFailure(failures, caseID, @"hygiene.lock", @"batch lock remained held"); validated = NO;
    }
    if (PXFITrackedDescriptorCount() != 0 || PXFITrackedDirectoryCount() != 0) {
        PXFIAddFailure(failures, caseID, @"hygiene.descriptor", @"tracked batch descriptor remained"); validated = NO;
    }
    PXFIRemoveRoot(root);
    return validated;
}

static NSString *PXFIGroupExpectedCrashPhase(NSInteger number) {
    if (number == 25 || number == 26) return @"prepared";
    if (number == 27 || number == 28) return @"quarantined";
    if (number == 29) return @"installed";
    if (number == 30) return @"committed";
    return nil;
}

static void PXFIGroupConfigureCrash(NSInteger number) {
    switch (number) {
        case 25:
            PXFIConfigureRule(PXFIPrimitiveFsync, PXFISemanticEventJournalPublicationDirectoryFsync, 1,
                              PXFIFaultActionCrashAfterSuccess, 0, 0, 0); break;
        case 26:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventTargetToOriginalMove, 3,
                              PXFIFaultActionCrashAfterSuccess, 0, 0, 0); break;
        case 27:
            PXFIConfigureRule(PXFIPrimitiveFsync, PXFISemanticEventJournalPublicationDirectoryFsync, 2,
                              PXFIFaultActionCrashAfterSuccess, 0, 0, 0); break;
        case 28:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventStageToTargetMove, 3,
                              PXFIFaultActionCrashAfterSuccess, 0, 0, 0); break;
        case 29:
            PXFIConfigureRule(PXFIPrimitiveFsync, PXFISemanticEventJournalPublicationDirectoryFsync, 3,
                              PXFIFaultActionCrashAfterSuccess, 0, 0, 0); break;
        case 30:
            PXFIConfigureRule(PXFIPrimitiveFsync, PXFISemanticEventJournalPublicationDirectoryFsync, 4,
                              PXFIFaultActionCrashAfterSuccess, 0, 0, 0); break;
        default: break;
    }
}

static int PXFIGroupCrashChild(NSString *caseID, NSString *root) {
    PXFIAppGroupFixture *fixture = PXFIAppGroupFixtureAtRoot(root, NO);
    if (!fixture) return 2;
    PXFIResetState();
    PXFIConfigurePaths(root, @[fixture.targetA, fixture.targetB], @[fixture.stageA, fixture.stageB], @[]);
    NSError *error = nil;
    PXAppGroupRestoreTransaction *transaction =
        [PXAppGroupRestoreTransaction transactionForTargets:fixture.targets validatedStages:fixture.stages error:&error];
    if (!transaction || error) return 2;
    PXFIGroupConfigureCrash([[caseID substringFromIndex:1] integerValue]);
    NSError *warning = nil;
    [transaction commitWithCleanupWarning:&warning error:&error];
    return 2;
}

static int PXFIGroupRecoveryChild(NSString *caseID, NSString *root) {
    PXFIAppGroupFixture *fixture = PXFIAppGroupFixtureAtRoot(root, NO);
    if (!fixture) return 2;
    PXFIResetState();
    PXFIConfigurePaths(root, @[fixture.targetA, fixture.targetB], @[fixture.stageA, fixture.stageB], @[]);
    NSError *error = nil;
    PXAppGroupRestoreTransaction *transaction =
        [PXAppGroupRestoreTransaction transactionForTargets:fixture.targets validatedStages:fixture.stages error:&error];
    if (!transaction || error) return 2;
    NSString *state = PXFIGroupStateEquals(fixture, @"ORIGINAL") ? @"ORIGINAL" :
                      (PXFIGroupStateEquals(fixture, @"INSTALLED") ? @"INSTALLED" : @"MIXED");
    NSDictionary *result = @{
        @"recovered": @(transaction.recoveredStaleBatchCount),
        @"state": state,
        @"workspaceCount": @(PXFIGroupAllWorkspaces(fixture).count)
    };
    transaction = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:result format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
    return data && PXFIWriteFile([root stringByAppendingPathComponent:@"recovery-result.plist"], data, 0600) ? 0 : 2;
}

static BOOL PXFIRunOneGroupCrashCase(NSString *caseID, NSMutableArray<NSDictionary *> *failures) {
    NSString *root = PXFINewTemporaryRoot();
    if (!root) { PXFIAddFailure(failures, caseID, @"fixture.root", @"fixture root creation failed"); return NO; }
    PXFIAppGroupFixture *fixture = PXFIAppGroupFixtureAtRoot(root, YES);
    if (!fixture) { PXFIRemoveRoot(root); PXFIAddFailure(failures, caseID, @"fixture.layout", @"fixture layout failed"); return NO; }
    NSDictionary *initial = PXFISnapshot(root);
    int status = 0; BOOL ok = initial &&
        PXFISpawnAndWait(@[@"--child", caseID, root], &status) &&
        WIFSIGNALED(status) && WTERMSIG(status) == SIGKILL;
    if (!ok) PXFIAddFailure(failures, caseID, @"crash.sigkill", @"batch child did not terminate by SIGKILL");
    NSDictionary *residue = PXFISnapshot(root);
    if (!residue || [residue isEqualToDictionary:initial]) {
        PXFIAddFailure(failures, caseID, @"crash.residue", @"batch crash residue did not preserve transaction evidence");
        ok = NO;
    }
    NSInteger number = [[caseID substringFromIndex:1] integerValue];
    if (![[PXFIGroupDurablePhase(fixture) ?: @""] isEqualToString:PXFIGroupExpectedCrashPhase(number)]) {
        PXFIAddFailure(failures, caseID, @"crash.phase", @"leader durable phase differed"); ok = NO;
    }
    int recoveryStatus = 0;
    if (!PXFISpawnAndWait(@[@"--recover", caseID, root], &recoveryStatus) || !WIFEXITED(recoveryStatus) || WEXITSTATUS(recoveryStatus) != 0) {
        PXFIAddFailure(failures, caseID, @"recovery.process", @"fresh batch recovery failed"); ok = NO;
    } else {
        NSString *resultPath = [root stringByAppendingPathComponent:@"recovery-result.plist"];
        NSData *data = [NSData dataWithContentsOfFile:resultPath options:0 error:nil];
        NSDictionary *result = data ? [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:nil] : nil;
        NSString *expectedState = number == 30 ? @"INSTALLED" : @"ORIGINAL";
        if (![result isKindOfClass:[NSDictionary class]] || [result[@"recovered"] unsignedIntegerValue] != 1 ||
            ![result[@"state"] isEqualToString:expectedState] || [result[@"workspaceCount"] unsignedIntegerValue] != 0) {
            PXFIAddFailure(failures, caseID, @"recovery.result", @"batch stale-recovery result differed"); ok = NO;
        }
        [[NSFileManager defaultManager] removeItemAtPath:resultPath error:nil];
    }
    if (!PXFIAcquireAndReleaseRealLock(fixture.targetA) || !PXFIAcquireAndReleaseRealLock(fixture.targetB)) {
        PXFIAddFailure(failures, caseID, @"hygiene.lock", @"batch recovery retained lock"); ok = NO;
    }
    PXFIRemoveRoot(root);
    return ok;
}

static int PXFIRunAllCases(void) {
    NSMutableArray<NSDictionary *> *failures = [NSMutableArray array];
    NSUInteger passed = 0;
    for (NSString *caseID in PXFIOrderedCaseIDs()) {
        BOOL ok = [[caseID substringFromIndex:1] integerValue] >= 25
            ? PXFIRunOneGroupCrashCase(caseID, failures)
            : PXFIRunOneGroupNormalCase(caseID, failures);
        if (ok) passed++;
    }
    if (failures.count || passed != 30) {
        for (NSDictionary *failure in PXFISortedFailures(failures)) {
            fprintf(stderr, "%s %s: %s\n", [failure[@"case"] UTF8String], [failure[@"assertion"] UTF8String], [failure[@"message"] UTF8String]);
        }
        return 1;
    }
    printf("transaction fault cases [app-group]: PASS (30/30)\n");
    return 0;
}

static int PXFIInternalChild(NSString *caseID, NSString *root) {
    if (![root isKindOfClass:[NSString class]] || !root.isAbsolutePath) return 2;
    if ([caseID hasPrefix:@"SELFTEST-KILL-"]) return PXFICommonSelfTestChild(caseID);
    if ([caseID hasPrefix:@"G"] && [[caseID substringFromIndex:1] integerValue] >= 25) return PXFIGroupCrashChild(caseID, root);
    return 2;
}

static int PXFIInternalRecover(NSString *caseID, NSString *root) {
    if (![root isKindOfClass:[NSString class]] || !root.isAbsolutePath) return 2;
    if ([caseID isEqualToString:@"SELFTEST-OK"]) return 0;
    if ([caseID hasPrefix:@"G"] && [[caseID substringFromIndex:1] integerValue] >= 25) return PXFIGroupRecoveryChild(caseID, root);
    return 2;
}

#elif PXFI_DOMAIN_OPTIONAL

@interface PXFIOptionalFixture : NSObject
@property (nonatomic, copy) NSString *root;
@property (nonatomic, copy) NSString *contentsDestination;
@property (nonatomic, copy) NSString *objectAuthority;
@property (nonatomic, copy) NSString *directoryDestination;
@property (nonatomic, copy) NSString *fileDestination;
@property (nonatomic, copy) NSString *contentsStage;
@property (nonatomic, copy) NSString *directoryStage;
@property (nonatomic, copy) NSString *fileStage;
@property (nonatomic, strong) PXOptionalRestoreTransactionItem *contentsItem;
@property (nonatomic, strong) PXOptionalRestoreTransactionItem *directoryItem;
@property (nonatomic, strong) PXOptionalRestoreTransactionItem *fileItem;
@end
@implementation PXFIOptionalFixture @end

static NSData *PXFIOptionalBytes(NSString *value) {
    return [value dataUsingEncoding:NSUTF8StringEncoding];
}

static NSDictionary *PXFIOptionalAcceptedDirectoryStage(BOOL contentsKind) {
    return @{
        @"entryCount": @2,
        @"regularFileCount": @2,
        @"directoryCount": @0,
        @"regularFileBytes": @34,
        @"treeSHA256": contentsKind
            ? @"6b08df5ab0af7f546e9bda5c995ffd925469b792058f1481ee57aa4387313f1c"
            : @"0bc993f9b915c1077b1280a8de07b5417795bd675a657415ea97932a22177296"
    };
}

static PXValidatedMainDataStage *PXFIOptionalDirectoryStage(NSString *root,
                                                             NSString *path,
                                                             BOOL contentsKind,
                                                             BOOL verifyCurrentTree) {
    NSDictionary *accepted = PXFIOptionalAcceptedDirectoryStage(contentsKind);
    if (verifyCurrentTree) {
        NSDictionary *actual = PXFITreeDescription(path);
        if (!actual || ![actual isEqualToDictionary:accepted]) return nil;
    }
    return [PXValidatedMainDataStage
        pxfi_stageWithWorkspaceRootPath:root
        dataPath:path
        entryCount:[accepted[@"entryCount"] unsignedIntegerValue]
        regularFileCount:[accepted[@"regularFileCount"] unsignedIntegerValue]
        directoryCount:[accepted[@"directoryCount"] unsignedIntegerValue]
        regularFileBytes:[accepted[@"regularFileBytes"] unsignedLongLongValue]
        treeSHA256:accepted[@"treeSHA256"]];
}

static PXFIOptionalFixture *PXFIOptionalFixtureAtRoot(NSString *root, BOOL create) {
    if (![root isKindOfClass:[NSString class]] || !root.isAbsolutePath) return nil;
    PXFIOptionalFixture *fixture = [[PXFIOptionalFixture alloc] init];
    fixture.root = root;
    fixture.contentsDestination = [root stringByAppendingPathComponent:@"contents-authority"];
    fixture.objectAuthority = [root stringByAppendingPathComponent:@"object-authority"];
    fixture.directoryDestination = [fixture.objectAuthority stringByAppendingPathComponent:@"directory-object"];
    fixture.fileDestination = [fixture.objectAuthority stringByAppendingPathComponent:@"file-object.bin"];
    fixture.contentsStage = [root stringByAppendingPathComponent:@"contents-stage"];
    fixture.directoryStage = [root stringByAppendingPathComponent:@"directory-stage"];
    fixture.fileStage = [root stringByAppendingPathComponent:@"file-stage.bin"];
    if (create) {
        BOOL made = PXFICreateDirectory(fixture.contentsDestination, 0700) &&
                    PXFICreateDirectory(fixture.objectAuthority, 0700) &&
                    PXFICreateDirectory(fixture.directoryDestination, 0700) &&
                    PXFICreateDirectory(fixture.contentsStage, 0700) &&
                    PXFICreateDirectory(fixture.directoryStage, 0700) &&
                    PXFIWriteFile([fixture.contentsDestination stringByAppendingPathComponent:@"old-c-1.txt"], PXFIOptionalBytes(@"optional-old-c-1\n"), 0600) &&
                    PXFIWriteFile([fixture.contentsDestination stringByAppendingPathComponent:@"old-c-2.txt"], PXFIOptionalBytes(@"optional-old-c-2\n"), 0600) &&
                    PXFIWriteFile([fixture.contentsStage stringByAppendingPathComponent:@"new-c-1.txt"], PXFIOptionalBytes(@"optional-new-c-1\n"), 0600) &&
                    PXFIWriteFile([fixture.contentsStage stringByAppendingPathComponent:@"new-c-2.txt"], PXFIOptionalBytes(@"optional-new-c-2\n"), 0600) &&
                    PXFIWriteFile([fixture.directoryDestination stringByAppendingPathComponent:@"old-d-1.txt"], PXFIOptionalBytes(@"optional-old-d-1\n"), 0600) &&
                    PXFIWriteFile([fixture.directoryDestination stringByAppendingPathComponent:@"old-d-2.txt"], PXFIOptionalBytes(@"optional-old-d-2\n"), 0600) &&
                    PXFIWriteFile([fixture.directoryStage stringByAppendingPathComponent:@"new-d-1.txt"], PXFIOptionalBytes(@"optional-new-d-1\n"), 0600) &&
                    PXFIWriteFile([fixture.directoryStage stringByAppendingPathComponent:@"new-d-2.txt"], PXFIOptionalBytes(@"optional-new-d-2\n"), 0600) &&
                    PXFIWriteFile(fixture.fileDestination, PXFIOptionalBytes(@"optional-old-file\n"), 0600) &&
                    PXFIWriteFile(fixture.fileStage, PXFIOptionalBytes(@"optional-new-file\n"), 0600);
        if (!made) return nil;
    }
    PXValidatedMainDataStage *contentsStage =
        PXFIOptionalDirectoryStage(root, fixture.contentsStage, YES, create);
    PXValidatedMainDataStage *directoryStage =
        PXFIOptionalDirectoryStage(root, fixture.directoryStage, NO, create);
    NSData *fileData = create
        ? [NSData dataWithContentsOfFile:fixture.fileStage options:0 error:nil]
        : nil;
    NSString *acceptedFileDigest =
        @"34562f67d069ffe930763d61624d50e6dfc1d2be66e6ac716311208ea1e6388a";
    if (create && (!fileData || fileData.length != 18 ||
                   ![PXFILowercaseSHA256(fileData) isEqualToString:acceptedFileDigest])) return nil;
    PXValidatedOptionalFileStage *fileStage = [PXValidatedOptionalFileStage
        pxfi_stageWithWorkspaceRootPath:root filePath:fixture.fileStage
        byteCount:18 sha256:acceptedFileDigest];
    NSError *itemError = nil;
    fixture.contentsItem = [PXOptionalRestoreTransactionItem
        directoryContentsItemWithDestinationPath:fixture.contentsDestination
        validatedStage:contentsStage error:&itemError];
    if (!fixture.contentsItem || itemError) return nil;
    fixture.directoryItem = [PXOptionalRestoreTransactionItem
        directoryObjectItemWithDestinationPath:fixture.directoryDestination
        validatedStage:directoryStage error:&itemError];
    if (!fixture.directoryItem || itemError) return nil;
    fixture.fileItem = [PXOptionalRestoreTransactionItem
        fileObjectItemWithDestinationPath:fixture.fileDestination
        validatedStage:fileStage error:&itemError];
    if (!fixture.fileItem || itemError) return nil;
    return fixture;
}

static NSArray<PXOptionalRestoreTransactionItem *> *PXFIOptionalItemsForCase(PXFIOptionalFixture *fixture,
                                                                              NSInteger number) {
    if (number == 3) return @[fixture.contentsItem];
    if (number == 4) return @[fixture.directoryItem];
    if (number == 5) return @[fixture.fileItem];
    return @[fixture.fileItem, fixture.contentsItem, fixture.directoryItem];
}

static NSString *PXFIOptionalContentsState(PXFIOptionalFixture *fixture) {
    NSDictionary *files = PXFIFlatRegularFiles(fixture.contentsDestination);
    NSDictionary *original = @{
        @"old-c-1.txt": PXFIOptionalBytes(@"optional-old-c-1\n"),
        @"old-c-2.txt": PXFIOptionalBytes(@"optional-old-c-2\n")
    };
    NSDictionary *installed = @{
        @"new-c-1.txt": PXFIOptionalBytes(@"optional-new-c-1\n"),
        @"new-c-2.txt": PXFIOptionalBytes(@"optional-new-c-2\n")
    };
    if ([files isEqualToDictionary:original]) return @"ORIGINAL";
    if ([files isEqualToDictionary:installed]) return @"INSTALLED";
    return @"MIXED";
}

static NSString *PXFIOptionalDirectoryState(PXFIOptionalFixture *fixture) {
    struct stat value; memset(&value, 0, sizeof(value));
    if (lstat(fixture.directoryDestination.fileSystemRepresentation, &value) != 0 || !S_ISDIR(value.st_mode)) return @"MIXED";
    NSDictionary *files = PXFIFlatRegularFiles(fixture.directoryDestination);
    NSDictionary *original = @{
        @"old-d-1.txt": PXFIOptionalBytes(@"optional-old-d-1\n"),
        @"old-d-2.txt": PXFIOptionalBytes(@"optional-old-d-2\n")
    };
    NSDictionary *installed = @{
        @"new-d-1.txt": PXFIOptionalBytes(@"optional-new-d-1\n"),
        @"new-d-2.txt": PXFIOptionalBytes(@"optional-new-d-2\n")
    };
    if ([files isEqualToDictionary:original]) return @"ORIGINAL";
    if ([files isEqualToDictionary:installed]) return @"INSTALLED";
    return @"MIXED";
}

static NSString *PXFIOptionalFileState(PXFIOptionalFixture *fixture) {
    NSData *data = [NSData dataWithContentsOfFile:fixture.fileDestination options:0 error:nil];
    if ([data isEqualToData:PXFIOptionalBytes(@"optional-old-file\n")]) return @"ORIGINAL";
    if ([data isEqualToData:PXFIOptionalBytes(@"optional-new-file\n")]) return @"INSTALLED";
    return @"MIXED";
}

static BOOL PXFIOptionalAllState(PXFIOptionalFixture *fixture, NSString *state) {
    return [PXFIOptionalContentsState(fixture) isEqualToString:state] &&
           [PXFIOptionalDirectoryState(fixture) isEqualToString:state] &&
           [PXFIOptionalFileState(fixture) isEqualToString:state];
}

static NSArray<NSString *> *PXFIOptionalAllWorkspaces(PXFIOptionalFixture *fixture) {
    return [PXFIWorkspacePaths(fixture.contentsDestination)
        arrayByAddingObjectsFromArray:PXFIWorkspacePaths(fixture.objectAuthority)];
}

static NSString *PXFIOptionalDurablePhase(PXFIOptionalFixture *fixture) {
    NSMutableArray<NSString *> *phases = [NSMutableArray array];
    for (NSString *workspace in PXFIOptionalAllWorkspaces(fixture)) {
        NSString *phase = PXFIJournalPhaseAtWorkspace(workspace);
        if (phase) [phases addObject:phase];
    }
    return phases.count == 1 ? phases.firstObject : nil;
}

static void PXFIOptionalConfigureCommitCase(NSInteger number) {
    switch (number) {
        case 8:
            PXFIConfigureRule(PXFIPrimitiveRead, PXFISemanticEventReplacementRead, 1,
                              PXFIFaultActionEINTRThenSuccess, EINTR, 1, 0); break;
        case 9:
            PXFIConfigureRule(PXFIPrimitiveMkdirAt, PXFISemanticEventWorkspaceCreation, 1,
                              PXFIFaultActionFailBefore, ENOSPC, 0, 0); break;
        case 10:
            PXFIConfigureRule(PXFIPrimitiveOpenAt, PXFISemanticEventReplacementOpen, 1,
                              PXFIFaultActionFailBefore, EMFILE, 0, 0); break;
        case 11:
            PXFIConfigureRule(PXFIPrimitiveRead, PXFISemanticEventReplacementRead, 1,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 12:
            PXFIConfigureRule(PXFIPrimitiveWrite, PXFISemanticEventReplacementWrite, 1,
                              PXFIFaultActionFailBefore, ENOSPC, 0, 0); break;
        case 13:
            PXFIConfigureRule(PXFIPrimitiveFsync, PXFISemanticEventReplacementFsync, 1,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 14:
            PXFIConfigureRule(PXFIPrimitiveWrite, PXFISemanticEventJournalTemporaryWrite, 1,
                              PXFIFaultActionFailBefore, ENOSPC, 0, 0); break;
        case 15:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventTargetToOriginalMove, 2,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 16:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventTargetToOriginalMove, 4,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 17:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventTargetToOriginalMove, 1,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 18:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventJournalPublicationRename, 2,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 19:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventStageToTargetMove, 2,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 20:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventStageToTargetMove, 4,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 21:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventStageToTargetMove, 1,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 22:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventJournalPublicationRename, 3,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 23:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventJournalPublicationRename, 4,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 24:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventJournalPublicationRename, 4,
                              PXFIFaultActionFailBefore, EIO, 0, 0);
            PXFIConfigureSecondaryRule(PXFIPrimitiveRenameAt, PXFISemanticEventTargetToNewMove, 1,
                                       PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 25:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventJournalPublicationRename, 4,
                              PXFIFaultActionFailBefore, EIO, 0, 0);
            PXFIConfigureSecondaryRule(PXFIPrimitiveRenameAt, PXFISemanticEventOriginalToTargetRestore, 1,
                                       PXFIFaultActionFailBefore, EIO, 0, 0); break;
        case 26:
            PXFIConfigureRule(PXFIPrimitiveUnlinkAt, PXFISemanticEventWorkspaceDirectoryRemoval, 1,
                              PXFIFaultActionFailBefore, EIO, 0, 0); break;
        default: break;
    }
}

static NSDictionary *PXFIOptionalExpectedError(NSInteger number) {
    if (number == 2) return @{@"code": @(PXOptionalRestoreTransactionErrorInvalidInput), @"field": @"$"};
    if (number == 6) return @{@"code": @(PXOptionalRestoreTransactionErrorLockFailed), @"field": @"$.locks"};
    if (number == 7) return @{@"code": @(PXOptionalRestoreTransactionErrorCrossDeviceBoundary), @"field": @"$.stage"};
    if (number == 9) return @{@"code": @(PXOptionalRestoreTransactionErrorWorkspaceCreationFailed), @"field": @"$.workspace"};
    if (number == 10) return @{@"code": @(PXOptionalRestoreTransactionErrorReplacementPreparationFailed), @"field": @"$.replacement"};
    if (number >= 11 && number <= 13) return @{@"code": @(PXOptionalRestoreTransactionErrorReplacementMismatch), @"field": @"$.replacement"};
    if (number == 14 || number == 18 || number == 22 || number == 23) return @{@"code": @(PXOptionalRestoreTransactionErrorJournalCreationFailed), @"field": @"$.journal"};
    if (number >= 15 && number <= 17) return @{@"code": @(PXOptionalRestoreTransactionErrorQuarantineFailed), @"field": @"$.transaction.quarantine"};
    if (number >= 19 && number <= 21) return @{@"code": @(PXOptionalRestoreTransactionErrorCommitFailed), @"field": @"$.transaction.commit"};
    if (number == 24) return @{@"code": @(PXOptionalRestoreTransactionErrorRollbackFailed), @"field": @"$.transaction.rollback.new"};
    if (number == 25) return @{@"code": @(PXOptionalRestoreTransactionErrorRollbackFailed), @"field": @"$.transaction.rollback.original"};
    return nil;
}

static BOOL PXFIOptionalSelectedState(PXFIOptionalFixture *fixture, NSInteger number, NSString *state) {
    if (number == 3) return [PXFIOptionalContentsState(fixture) isEqualToString:state];
    if (number == 4) return [PXFIOptionalDirectoryState(fixture) isEqualToString:state];
    if (number == 5) return [PXFIOptionalFileState(fixture) isEqualToString:state];
    return PXFIOptionalAllState(fixture, state);
}

static BOOL PXFIOptionalValidateCase(NSString *caseID,
                                     PXFIOptionalFixture *fixture,
                                     PXOptionalRestoreTransaction *transaction,
                                     BOOL factoryNil,
                                     BOOL commitResult,
                                     NSError *error,
                                     NSError *cleanupWarning,
                                     NSMutableArray<NSDictionary *> *failures) {
    NSInteger number = [[caseID substringFromIndex:1] integerValue];
    NSArray *privateValues = @[fixture.contentsDestination, fixture.objectAuthority,
                               fixture.directoryDestination, fixture.fileDestination,
                               fixture.contentsStage, fixture.directoryStage, fixture.fileStage,
                               @"optional-old", @"optional-new"];
    BOOL ok = YES;
#define PXFI_OPTIONAL_ASSERT(condition, name, message) do { if (!(condition)) { PXFIAddFailure(failures, caseID, name, message); ok = NO; } } while (0)
    if (number == 6 || number == 7) {
        NSDictionary *expected = PXFIOptionalExpectedError(number);
        PXFI_OPTIONAL_ASSERT(factoryNil, @"factory.nil", @"optional factory result differed");
        PXFI_OPTIONAL_ASSERT(PXFIErrorMatches(error, PXOptionalRestoreTransactionErrorDomain,
                                              [expected[@"code"] integerValue], PXOptionalRestoreTransactionErrorFieldPathKey,
                                              expected[@"field"], fixture.root, privateValues),
                             @"factory.error", @"optional factory error differed");
        PXFI_OPTIONAL_ASSERT(PXFIOptionalAllState(fixture, @"ORIGINAL"), @"factory.original", @"factory failure changed optional destinations");
        return ok;
    }
    PXFI_OPTIONAL_ASSERT(!factoryNil && transaction != nil, @"factory.nonnull", @"optional transaction factory failed");
    if (!transaction) return NO;
    if (number == 1 || (number >= 3 && number <= 5) || number == 8) {
        PXFI_OPTIONAL_ASSERT(commitResult && error == nil && cleanupWarning == nil, @"commit.yes", @"optional clean commit failed");
        PXFI_OPTIONAL_ASSERT(transaction.committed && !transaction.rollbackPerformed && !transaction.rollbackComplete,
                             @"public.state", @"optional clean public state differed");
        PXFI_OPTIONAL_ASSERT(transaction.itemCount == PXFIOptionalItemsForCase(fixture, number).count,
                             @"public.itemCount", @"optional item count differed");
        PXFI_OPTIONAL_ASSERT(PXFIOptionalSelectedState(fixture, number, @"INSTALLED"),
                             @"filesystem.installed", @"optional selected replacement was not installed");
        if (number == 3) {
            PXFI_OPTIONAL_ASSERT([PXFIOptionalDirectoryState(fixture) isEqualToString:@"ORIGINAL"] &&
                                 [PXFIOptionalFileState(fixture) isEqualToString:@"ORIGINAL"],
                                 @"filesystem.unselected", @"unselected optional objects changed");
        } else if (number == 4) {
            PXFI_OPTIONAL_ASSERT([PXFIOptionalContentsState(fixture) isEqualToString:@"ORIGINAL"] &&
                                 [PXFIOptionalFileState(fixture) isEqualToString:@"ORIGINAL"],
                                 @"filesystem.unselected", @"unselected optional objects changed");
        } else if (number == 5) {
            PXFI_OPTIONAL_ASSERT([PXFIOptionalContentsState(fixture) isEqualToString:@"ORIGINAL"] &&
                                 [PXFIOptionalDirectoryState(fixture) isEqualToString:@"ORIGINAL"],
                                 @"filesystem.unselected", @"unselected optional objects changed");
        }
        PXFI_OPTIONAL_ASSERT(PXFIOptionalAllWorkspaces(fixture).count == 0, @"workspace.cleaned", @"optional clean commit retained workspace");
    } else if (number == 2) {
        NSDictionary *expected = PXFIOptionalExpectedError(number);
        PXFI_OPTIONAL_ASSERT(!commitResult && PXFIErrorMatches(error, PXOptionalRestoreTransactionErrorDomain,
                                                               [expected[@"code"] integerValue], PXOptionalRestoreTransactionErrorFieldPathKey,
                                                               expected[@"field"], fixture.root, privateValues),
                             @"second.error", @"optional second commit error differed");
        PXFI_OPTIONAL_ASSERT(transaction.committed && PXFIOptionalAllState(fixture, @"INSTALLED"),
                             @"second.state", @"optional second commit changed installed state");
    } else if (number >= 9 && number <= 13) {
        NSDictionary *expected = PXFIOptionalExpectedError(number);
        PXFI_OPTIONAL_ASSERT(!commitResult && PXFIErrorMatches(error, PXOptionalRestoreTransactionErrorDomain,
                                                               [expected[@"code"] integerValue], PXOptionalRestoreTransactionErrorFieldPathKey,
                                                               expected[@"field"], fixture.root, privateValues),
                             @"prepare.error", @"optional replacement-preparation error differed");
        PXFI_OPTIONAL_ASSERT(!transaction.committed && !transaction.rollbackPerformed && !transaction.rollbackComplete,
                             @"prepare.state", @"unprepared optional failure entered rollback");
        PXFI_OPTIONAL_ASSERT(PXFIOptionalAllState(fixture, @"ORIGINAL"), @"prepare.original", @"optional preparation failure changed originals");
    } else if (number >= 14 && number <= 23) {
        NSDictionary *expected = PXFIOptionalExpectedError(number);
        PXFI_OPTIONAL_ASSERT(!commitResult && PXFIErrorMatches(error, PXOptionalRestoreTransactionErrorDomain,
                                                               [expected[@"code"] integerValue], PXOptionalRestoreTransactionErrorFieldPathKey,
                                                               expected[@"field"], fixture.root, privateValues),
                             @"operation.error", @"optional operation error differed");
        PXFI_OPTIONAL_ASSERT(!transaction.committed && transaction.rollbackPerformed && transaction.rollbackComplete,
                             @"rollback.complete", @"optional rollback did not complete");
        PXFI_OPTIONAL_ASSERT(PXFIOptionalAllState(fixture, @"ORIGINAL"), @"rollback.original", @"optional rollback left mixed state");
        PXFI_OPTIONAL_ASSERT(PXFIOptionalAllWorkspaces(fixture).count == 0, @"rollback.cleaned", @"optional completed rollback retained workspace");
    } else if (number == 24 || number == 25) {
        NSDictionary *expected = PXFIOptionalExpectedError(number);
        PXFI_OPTIONAL_ASSERT(!commitResult && PXFIErrorMatches(error, PXOptionalRestoreTransactionErrorDomain,
                                                               [expected[@"code"] integerValue], PXOptionalRestoreTransactionErrorFieldPathKey,
                                                               expected[@"field"], fixture.root, privateValues),
                             @"rollback.error", @"optional rollback failure error differed");
        PXFI_OPTIONAL_ASSERT(!transaction.committed && transaction.rollbackPerformed && !transaction.rollbackComplete,
                             @"rollback.incomplete", @"optional rollback failure was normalized into completion");
        PXFI_OPTIONAL_ASSERT(PXFIOptionalAllWorkspaces(fixture).count >= 1, @"rollback.evidence", @"optional rollback evidence was not retained");
    } else if (number == 26) {
        PXFI_OPTIONAL_ASSERT(commitResult && error == nil, @"cleanup.commit", @"optional cleanup warning changed commit result");
        PXFI_OPTIONAL_ASSERT(PXFIErrorMatches(cleanupWarning, PXOptionalRestoreTransactionErrorDomain,
                                              PXOptionalRestoreTransactionErrorCleanupFailed,
                                              PXOptionalRestoreTransactionErrorFieldPathKey,
                                              @"$.transaction.cleanup", fixture.root, privateValues),
                             @"cleanup.warning", @"optional cleanup warning differed");
        PXFI_OPTIONAL_ASSERT(transaction.committed && PXFIOptionalAllState(fixture, @"INSTALLED"),
                             @"cleanup.installed", @"optional cleanup warning damaged replacements");
        PXFI_OPTIONAL_ASSERT(PXFIOptionalAllWorkspaces(fixture).count >= 1, @"cleanup.evidence", @"optional cleanup evidence was not retained");
    }
#undef PXFI_OPTIONAL_ASSERT
    return ok;
}

static BOOL PXFIRunOneOptionalNormalCase(NSString *caseID, NSMutableArray<NSDictionary *> *failures) {
    NSString *root = PXFINewTemporaryRoot();
    if (!root) { PXFIAddFailure(failures, caseID, @"fixture.root", @"fixture root creation failed"); return NO; }
    PXFIOptionalFixture *fixture = PXFIOptionalFixtureAtRoot(root, YES);
    if (!fixture) { PXFIRemoveRoot(root); PXFIAddFailure(failures, caseID, @"fixture.layout", @"optional fixture layout failed"); return NO; }
    PXFIResetState();
    PXFIConfigurePaths(root, @[], @[fixture.fileStage, fixture.contentsStage, fixture.directoryStage],
                       @[fixture.contentsDestination, fixture.objectAuthority]);
    NSInteger number = [[caseID substringFromIndex:1] integerValue];
    int contentionDescriptor = -1;
    if (number == 6) {
        contentionDescriptor = open(fixture.contentsDestination.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        if (contentionDescriptor < 0 || flock(contentionDescriptor, LOCK_EX | LOCK_NB) != 0) {
            if (contentionDescriptor >= 0) close(contentionDescriptor);
            PXFIRemoveRoot(root); PXFIAddFailure(failures, caseID, @"fixture.lock", @"optional lock setup failed"); return NO;
        }
    }
    if (number == 7) {
        struct stat value; memset(&value, 0, sizeof(value)); lstat(fixture.fileStage.fileSystemRepresentation, &value);
        PXFIConfigureRule(PXFIPrimitiveFstat, PXFISemanticEventStageFstat, 1,
                          PXFIFaultActionMutateSuccessfulFstatDevice, 0, 0, value.st_dev + 1);
    }
    __block BOOL validated = NO;
    @autoreleasepool {
        NSError *factoryError = nil;
        NSArray *items = PXFIOptionalItemsForCase(fixture, number);
        PXOptionalRestoreTransaction *transaction = [PXOptionalRestoreTransaction transactionForItems:items error:&factoryError];
        if (contentionDescriptor >= 0) { flock(contentionDescriptor, LOCK_UN); close(contentionDescriptor); contentionDescriptor = -1; }
        if (!transaction) {
            validated = PXFIOptionalValidateCase(caseID, fixture, nil, YES, NO, factoryError, nil, failures);
        } else {
            PXFIOptionalConfigureCommitCase(number);
            NSError *warning = nil; NSError *commitError = nil;
            BOOL result = [transaction commitWithCleanupWarning:&warning error:&commitError];
            if (number == 2 && result) { warning = nil; commitError = nil; result = [transaction commitWithCleanupWarning:&warning error:&commitError]; }
            validated = PXFIOptionalValidateCase(caseID, fixture, transaction, NO, result, commitError, warning, failures);
            transaction = nil;
        }
    }
    unsigned expectedInjected = number <= 6 ? 0 : ((number == 24 || number == 25) ? 2 : 1);
    if (PXFIInjectedFaultCount() != expectedInjected) {
        PXFIAddFailure(failures, caseID, @"fault.consumed", @"optional fault consumption count differed");
        validated = NO;
    }
    if (contentionDescriptor >= 0) { flock(contentionDescriptor, LOCK_UN); close(contentionDescriptor); }
    if (!PXFIAcquireAndReleaseRealLock(fixture.contentsDestination) || !PXFIAcquireAndReleaseRealLock(fixture.objectAuthority)) {
        PXFIAddFailure(failures, caseID, @"hygiene.lock", @"optional authority lock remained held"); validated = NO;
    }
    if (PXFITrackedDescriptorCount() != 0 || PXFITrackedDirectoryCount() != 0) {
        PXFIAddFailure(failures, caseID, @"hygiene.descriptor", @"tracked optional descriptor remained"); validated = NO;
    }
    PXFIRemoveRoot(root);
    return validated;
}

static NSString *PXFIOptionalExpectedCrashPhase(NSInteger number) {
    if (number == 27 || number == 28) return @"prepared";
    if (number == 29) return @"installed";
    if (number == 30) return @"committed";
    return nil;
}

static void PXFIOptionalConfigureCrash(NSInteger number) {
    switch (number) {
        case 27:
            PXFIConfigureRule(PXFIPrimitiveFsync, PXFISemanticEventJournalPublicationDirectoryFsync, 1,
                              PXFIFaultActionCrashAfterSuccess, 0, 0, 0); break;
        case 28:
            PXFIConfigureRule(PXFIPrimitiveRenameAt, PXFISemanticEventTargetToOriginalMove, 2,
                              PXFIFaultActionCrashAfterSuccess, 0, 0, 0); break;
        case 29:
            PXFIConfigureRule(PXFIPrimitiveFsync, PXFISemanticEventJournalPublicationDirectoryFsync, 3,
                              PXFIFaultActionCrashAfterSuccess, 0, 0, 0); break;
        case 30:
            PXFIConfigureRule(PXFIPrimitiveFsync, PXFISemanticEventJournalPublicationDirectoryFsync, 4,
                              PXFIFaultActionCrashAfterSuccess, 0, 0, 0); break;
        default: break;
    }
}

static int PXFIOptionalCrashChild(NSString *caseID, NSString *root) {
    PXFIOptionalFixture *fixture = PXFIOptionalFixtureAtRoot(root, NO);
    if (!fixture) return 2;
    PXFIResetState();
    PXFIConfigurePaths(root, @[], @[fixture.fileStage, fixture.contentsStage, fixture.directoryStage],
                       @[fixture.contentsDestination, fixture.objectAuthority]);
    NSError *error = nil;
    PXOptionalRestoreTransaction *transaction = [PXOptionalRestoreTransaction
        transactionForItems:PXFIOptionalItemsForCase(fixture, [[caseID substringFromIndex:1] integerValue]) error:&error];
    if (!transaction || error) return 2;
    PXFIOptionalConfigureCrash([[caseID substringFromIndex:1] integerValue]);
    NSError *warning = nil;
    [transaction commitWithCleanupWarning:&warning error:&error];
    return 2;
}

static int PXFIOptionalRecoveryChild(NSString *caseID, NSString *root) {
    PXFIOptionalFixture *fixture = PXFIOptionalFixtureAtRoot(root, NO);
    if (!fixture) return 2;
    PXFIResetState();
    PXFIConfigurePaths(root, @[], @[fixture.fileStage, fixture.contentsStage, fixture.directoryStage],
                       @[fixture.contentsDestination, fixture.objectAuthority]);
    NSError *error = nil;
    PXOptionalRestoreTransaction *transaction = [PXOptionalRestoreTransaction
        transactionForItems:PXFIOptionalItemsForCase(fixture, [[caseID substringFromIndex:1] integerValue]) error:&error];
    if (!transaction || error) return 2;
    NSString *state = PXFIOptionalAllState(fixture, @"ORIGINAL") ? @"ORIGINAL" :
                      (PXFIOptionalAllState(fixture, @"INSTALLED") ? @"INSTALLED" : @"MIXED");
    NSDictionary *result = @{
        @"recovered": @(transaction.recoveredStaleTransactionCount),
        @"state": state,
        @"workspaceCount": @(PXFIOptionalAllWorkspaces(fixture).count)
    };
    transaction = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:result format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
    return data && PXFIWriteFile([root stringByAppendingPathComponent:@"recovery-result.plist"], data, 0600) ? 0 : 2;
}

static BOOL PXFIRunOneOptionalCrashCase(NSString *caseID, NSMutableArray<NSDictionary *> *failures) {
    NSString *root = PXFINewTemporaryRoot();
    if (!root) { PXFIAddFailure(failures, caseID, @"fixture.root", @"fixture root creation failed"); return NO; }
    PXFIOptionalFixture *fixture = PXFIOptionalFixtureAtRoot(root, YES);
    if (!fixture) { PXFIRemoveRoot(root); PXFIAddFailure(failures, caseID, @"fixture.layout", @"optional fixture layout failed"); return NO; }
    NSDictionary *initial = PXFISnapshot(root);
    int status = 0; BOOL ok = initial &&
        PXFISpawnAndWait(@[@"--child", caseID, root], &status) &&
        WIFSIGNALED(status) && WTERMSIG(status) == SIGKILL;
    if (!ok) PXFIAddFailure(failures, caseID, @"crash.sigkill", @"optional child did not terminate by SIGKILL");
    NSDictionary *residue = PXFISnapshot(root);
    if (!residue || [residue isEqualToDictionary:initial]) {
        PXFIAddFailure(failures, caseID, @"crash.residue", @"optional crash residue did not preserve transaction evidence");
        ok = NO;
    }
    NSInteger number = [[caseID substringFromIndex:1] integerValue];
    if (![[PXFIOptionalDurablePhase(fixture) ?: @""] isEqualToString:PXFIOptionalExpectedCrashPhase(number)]) {
        PXFIAddFailure(failures, caseID, @"crash.phase", @"optional durable phase differed"); ok = NO;
    }
    int recoveryStatus = 0;
    if (!PXFISpawnAndWait(@[@"--recover", caseID, root], &recoveryStatus) || !WIFEXITED(recoveryStatus) || WEXITSTATUS(recoveryStatus) != 0) {
        PXFIAddFailure(failures, caseID, @"recovery.process", @"fresh optional recovery failed"); ok = NO;
    } else {
        NSString *resultPath = [root stringByAppendingPathComponent:@"recovery-result.plist"];
        NSData *data = [NSData dataWithContentsOfFile:resultPath options:0 error:nil];
        NSDictionary *result = data ? [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:nil] : nil;
        NSString *expectedState = number == 30 ? @"INSTALLED" : @"ORIGINAL";
        if (![result isKindOfClass:[NSDictionary class]] || [result[@"recovered"] unsignedIntegerValue] != 1 ||
            ![result[@"state"] isEqualToString:expectedState] || [result[@"workspaceCount"] unsignedIntegerValue] != 0) {
            PXFIAddFailure(failures, caseID, @"recovery.result", @"optional stale-recovery result differed"); ok = NO;
        }
        [[NSFileManager defaultManager] removeItemAtPath:resultPath error:nil];
    }
    if (!PXFIAcquireAndReleaseRealLock(fixture.contentsDestination) || !PXFIAcquireAndReleaseRealLock(fixture.objectAuthority)) {
        PXFIAddFailure(failures, caseID, @"hygiene.lock", @"optional recovery retained lock"); ok = NO;
    }
    PXFIRemoveRoot(root);
    return ok;
}

static int PXFIRunAllCases(void) {
    NSMutableArray<NSDictionary *> *failures = [NSMutableArray array];
    NSUInteger passed = 0;
    for (NSString *caseID in PXFIOrderedCaseIDs()) {
        BOOL ok = [[caseID substringFromIndex:1] integerValue] >= 27
            ? PXFIRunOneOptionalCrashCase(caseID, failures)
            : PXFIRunOneOptionalNormalCase(caseID, failures);
        if (ok) passed++;
    }
    if (failures.count || passed != 30) {
        for (NSDictionary *failure in PXFISortedFailures(failures)) {
            fprintf(stderr, "%s %s: %s\n", [failure[@"case"] UTF8String], [failure[@"assertion"] UTF8String], [failure[@"message"] UTF8String]);
        }
        return 1;
    }
    printf("transaction fault cases [optional]: PASS (30/30)\n");
    return 0;
}

static int PXFIInternalChild(NSString *caseID, NSString *root) {
    if (![root isKindOfClass:[NSString class]] || !root.isAbsolutePath) return 2;
    if ([caseID hasPrefix:@"SELFTEST-KILL-"]) return PXFICommonSelfTestChild(caseID);
    if ([caseID hasPrefix:@"O"] && [[caseID substringFromIndex:1] integerValue] >= 27) return PXFIOptionalCrashChild(caseID, root);
    return 2;
}

static int PXFIInternalRecover(NSString *caseID, NSString *root) {
    if (![root isKindOfClass:[NSString class]] || !root.isAbsolutePath) return 2;
    if ([caseID isEqualToString:@"SELFTEST-OK"]) return 0;
    if ([caseID hasPrefix:@"O"] && [[caseID substringFromIndex:1] integerValue] >= 27) return PXFIOptionalRecoveryChild(caseID, root);
    return 2;
}

#endif

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        PXFIExecutablePath = [[[NSProcessInfo processInfo] arguments].firstObject stringByStandardizingPath];
        if (argc == 2 && strcmp(argv[1], "--self-test") == 0) return PXFIRunSelfTests(YES);
        if (argc == 2 && strcmp(argv[1], "--run-all") == 0) {
            int selfTest = PXFIRunSelfTests(NO);
            return selfTest == 0 ? PXFIRunAllCases() : selfTest;
        }
        if (argc == 4 && strcmp(argv[1], "--child") == 0) {
            return PXFIInternalChild([NSString stringWithUTF8String:argv[2]], [NSString stringWithUTF8String:argv[3]]);
        }
        if (argc == 4 && strcmp(argv[1], "--recover") == 0) {
            return PXFIInternalRecover([NSString stringWithUTF8String:argv[2]], [NSString stringWithUTF8String:argv[3]]);
        }
        fprintf(stderr, "usage: transaction-fault-tests --self-test|--run-all\n");
        return 2;
    }
}
