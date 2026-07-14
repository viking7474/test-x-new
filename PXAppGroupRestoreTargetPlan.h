#import <Foundation/Foundation.h>

@class PXRestorePlan;
@class PXRestorePlanAppGroupItem;
@class PXResolvedContainer;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const PXAppGroupRestoreTargetPlanErrorDomain;
FOUNDATION_EXPORT NSString * const PXAppGroupRestoreTargetPlanErrorFieldPathKey;

typedef NS_ENUM(NSInteger, PXAppGroupRestoreTargetPlanErrorCode) {
    PXAppGroupRestoreTargetPlanErrorInvalidInput = 1,
    PXAppGroupRestoreTargetPlanErrorInvalidEntitlementSet = 2,
    PXAppGroupRestoreTargetPlanErrorUnentitledGroup = 3,
    PXAppGroupRestoreTargetPlanErrorResolverFailed = 4,
    PXAppGroupRestoreTargetPlanErrorValidatorFailed = 5,
    PXAppGroupRestoreTargetPlanErrorMissingTarget = 6,
    PXAppGroupRestoreTargetPlanErrorAmbiguousTarget = 7,
    PXAppGroupRestoreTargetPlanErrorInconsistentPlan = 8,
    PXAppGroupRestoreTargetPlanErrorLimitExceeded = 9,
};

__attribute__((objc_subclassing_restricted))
@interface PXAppGroupRestoreTarget : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSArray<NSString *> *groupIdentifiers;
@property (nonatomic, copy, readonly) NSArray<PXResolvedContainer *> *containerModels;
@property (nonatomic, copy, readonly) NSString *canonicalPath;
@property (nonatomic, copy, readonly) NSArray<PXRestorePlanAppGroupItem *> *planItems;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

__attribute__((objc_subclassing_restricted))
@interface PXAppGroupRestoreTargetPlan : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSArray<PXAppGroupRestoreTarget *> *targets;

+ (nullable instancetype)targetPlanForRestorePlan:(PXRestorePlan *)restorePlan
                         entitledGroupIdentifiers:(NSArray<NSString *> *)entitledGroupIdentifiers
                                            error:(NSError * _Nullable * _Nullable)error;

- (nullable PXAppGroupRestoreTarget *)targetForGroupIdentifier:(NSString *)groupIdentifier;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
