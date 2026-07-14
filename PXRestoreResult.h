#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, PXRestoreComponent) {
    PXRestoreComponentApplicationData = 1 << 0,
    PXRestoreComponentProfileAppData = 1 << 1,
    PXRestoreComponentGlobalSafari = 1 << 2,
    PXRestoreComponentAppGroups = 1 << 3,
    PXRestoreComponentSystemGlobal = 1 << 4,
    PXRestoreComponentSharedSystemDatabases = 1 << 5,
    PXRestoreComponentPreferences = 1 << 6,
    PXRestoreComponentKeychain = 1 << 7,
    PXRestoreComponentAll =
        PXRestoreComponentApplicationData |
        PXRestoreComponentProfileAppData |
        PXRestoreComponentGlobalSafari |
        PXRestoreComponentAppGroups |
        PXRestoreComponentSystemGlobal |
        PXRestoreComponentSharedSystemDatabases |
        PXRestoreComponentPreferences |
        PXRestoreComponentKeychain,
};

typedef NS_ENUM(NSInteger, PXRestoreComponentStatus) {
    PXRestoreComponentStatusSkipped = 0,
    PXRestoreComponentStatusNotAttempted = 1,
    PXRestoreComponentStatusSucceeded = 2,
    PXRestoreComponentStatusFailed = 3,
};

typedef NS_ENUM(NSInteger, PXRestoreRollbackStatus) {
    PXRestoreRollbackStatusNotPerformed = 0,
    PXRestoreRollbackStatusCompleted = 1,
    PXRestoreRollbackStatusIncomplete = 2,
};

__attribute__((objc_subclassing_restricted))
@interface PXRestoreFailure : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSString *domain;
@property (nonatomic, assign, readonly) NSInteger code;
@property (nonatomic, copy, readonly) NSString *message;

- (nullable instancetype)initWithDomain:(NSString *)domain
                                   code:(NSInteger)code
                                message:(NSString *)message
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

__attribute__((objc_subclassing_restricted))
@interface PXRestoreComponentResult : NSObject <NSCopying>

@property (nonatomic, assign, readonly) PXRestoreComponent component;
@property (nonatomic, assign, readonly) PXRestoreComponentStatus status;
@property (nonatomic, assign, readonly) NSUInteger plannedUnitCount;
@property (nonatomic, assign, readonly) NSUInteger committedUnitCount;
@property (nonatomic, assign, readonly) PXRestoreRollbackStatus rollbackStatus;
@property (nonatomic, copy, readonly) NSArray<NSString *> *warnings;
@property (nonatomic, copy, nullable, readonly) PXRestoreFailure *failure;

- (nullable instancetype)initWithComponent:(PXRestoreComponent)component
                                    status:(PXRestoreComponentStatus)status
                          plannedUnitCount:(NSUInteger)plannedUnitCount
                        committedUnitCount:(NSUInteger)committedUnitCount
                            rollbackStatus:(PXRestoreRollbackStatus)rollbackStatus
                                  warnings:(NSArray<NSString *> *)warnings
                                   failure:(nullable PXRestoreFailure *)failure
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

__attribute__((objc_subclassing_restricted))
@interface PXRestoreResult : NSObject <NSCopying>

@property (nonatomic, assign, readonly) PXRestoreComponent requestedComponents;
@property (nonatomic, copy, readonly) NSArray<PXRestoreComponentResult *> *componentResults;
@property (nonatomic, assign, readonly) PXRestoreComponent succeededComponents;
@property (nonatomic, assign, readonly) PXRestoreComponent skippedComponents;
@property (nonatomic, assign, readonly) PXRestoreComponent notAttemptedComponents;
@property (nonatomic, assign, readonly) PXRestoreComponent failedComponents;
@property (nonatomic, copy, readonly) NSArray<NSString *> *warnings;
@property (nonatomic, assign, readonly) BOOL hasWarnings;
@property (nonatomic, assign, readonly) BOOL hasFailures;
@property (nonatomic, assign, readonly) BOOL hasIncompleteRollback;
@property (nonatomic, assign, readonly) BOOL allRequestedComponentsSucceeded;

- (nullable instancetype)initWithRequestedComponents:(PXRestoreComponent)requestedComponents
                                    componentResults:(NSArray<PXRestoreComponentResult *> *)componentResults
                                            warnings:(NSArray<NSString *> *)warnings
    NS_DESIGNATED_INITIALIZER;

- (nullable PXRestoreComponentResult *)componentResultForComponent:(PXRestoreComponent)component;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
