#import "PXAppGroupRestoreTargetPlan.h"
#import "PXRestorePlan.h"
#import "PXResolvedContainer.h"
#import "AppGroupContainerResolver.h"
#import "PXDestructivePathValidator.h"

NSString * const PXAppGroupRestoreTargetPlanErrorDomain =
    @"com.hydra.projectx.app-group-restore-target-plan";
NSString * const PXAppGroupRestoreTargetPlanErrorFieldPathKey =
    @"PXAppGroupRestoreTargetPlanErrorFieldPathKey";

static const NSUInteger PXAppGroupRestoreTargetPlanMaximumPlannedItems = 256;
static const NSUInteger PXAppGroupRestoreTargetPlanMaximumEntitlements = 4096;
static const NSUInteger PXAppGroupRestoreTargetPlanMaximumTargets = 256;

static id PXAppGroupRestoreTargetPlanFail(NSError **error,
                                          PXAppGroupRestoreTargetPlanErrorCode code,
                                          NSString *fieldPath,
                                          NSString *description) {
    if (error) {
        *error = [NSError errorWithDomain:PXAppGroupRestoreTargetPlanErrorDomain
                                     code:code
                                 userInfo:@{
                                     NSLocalizedDescriptionKey: description,
                                     PXAppGroupRestoreTargetPlanErrorFieldPathKey: fieldPath
                                 }];
    }
    return nil;
}

static BOOL PXAppGroupRestoreTargetPlanStringContainsNUL(NSString *value) {
    for (NSUInteger index = 0; index < value.length; index++) {
        if ([value characterAtIndex:index] == 0) {
            return YES;
        }
    }
    return NO;
}

static BOOL PXAppGroupRestoreTargetPlanStringHasNonWhitespaceText(NSString *value) {
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    for (NSUInteger index = 0; index < value.length; index++) {
        if (![whitespace characterIsMember:[value characterAtIndex:index]]) {
            return YES;
        }
    }
    return NO;
}

static BOOL PXAppGroupRestoreTargetPlanBasicStringIsValid(id value) {
    return [value isKindOfClass:[NSString class]] &&
           [(NSString *)value length] > 0 &&
           !PXAppGroupRestoreTargetPlanStringContainsNUL((NSString *)value);
}

@interface PXAppGroupRestoreTarget ()
- (instancetype)initWithGroupIdentifiers:(NSArray<NSString *> *)groupIdentifiers
                          containerModels:(NSArray<PXResolvedContainer *> *)containerModels
                            canonicalPath:(NSString *)canonicalPath
                                planItems:(NSArray<PXRestorePlanAppGroupItem *> *)planItems;
@end

@implementation PXAppGroupRestoreTarget

- (instancetype)initWithGroupIdentifiers:(NSArray<NSString *> *)groupIdentifiers
                          containerModels:(NSArray<PXResolvedContainer *> *)containerModels
                            canonicalPath:(NSString *)canonicalPath
                                planItems:(NSArray<PXRestorePlanAppGroupItem *> *)planItems {
    self = [super init];
    if (self) {
        _groupIdentifiers = [groupIdentifiers copy];
        _containerModels = [containerModels copy];
        _canonicalPath = [canonicalPath copy];
        _planItems = [planItems copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

@end

@interface PXAppGroupRestoreTargetPlan ()
@property (nonatomic, copy, readonly) NSDictionary<NSString *, PXAppGroupRestoreTarget *> *targetByGroupIdentifier;
- (instancetype)initWithTargets:(NSArray<PXAppGroupRestoreTarget *> *)targets
       targetByGroupIdentifier:(NSDictionary<NSString *, PXAppGroupRestoreTarget *> *)targetByGroupIdentifier;
@end

@interface PXAppGroupRestoreTargetBuilder : NSObject
@property (nonatomic, copy) NSString *canonicalPath;
@property (nonatomic, strong) NSMutableArray<NSString *> *groupIdentifiers;
@property (nonatomic, strong) NSMutableArray<PXResolvedContainer *> *containerModels;
@property (nonatomic, strong) NSMutableArray<PXRestorePlanAppGroupItem *> *planItems;
@end

@implementation PXAppGroupRestoreTargetBuilder
@end

@implementation PXAppGroupRestoreTargetPlan

- (instancetype)initWithTargets:(NSArray<PXAppGroupRestoreTarget *> *)targets
       targetByGroupIdentifier:(NSDictionary<NSString *, PXAppGroupRestoreTarget *> *)targetByGroupIdentifier {
    self = [super init];
    if (self) {
        _targets = [targets copy];
        _targetByGroupIdentifier = [targetByGroupIdentifier copy];
    }
    return self;
}

+ (instancetype)targetPlanForRestorePlan:(PXRestorePlan *)restorePlan
                entitledGroupIdentifiers:(NSArray<NSString *> *)entitledGroupIdentifiers
                                   error:(NSError **)error {
    if (error) {
        *error = nil;
    }

    if (![restorePlan isKindOfClass:[PXRestorePlan class]] ||
        ![entitledGroupIdentifiers isKindOfClass:[NSArray class]]) {
        return PXAppGroupRestoreTargetPlanFail(error,
                                               PXAppGroupRestoreTargetPlanErrorInvalidInput,
                                               @"$",
                                               @"The App Group restore target-plan input is invalid.");
    }

    NSArray *planItems = restorePlan.appGroupItems;
    if (![planItems isKindOfClass:[NSArray class]]) {
        return PXAppGroupRestoreTargetPlanFail(error,
                                               PXAppGroupRestoreTargetPlanErrorInconsistentPlan,
                                               @"$.appGroups",
                                               @"The accepted App Group restore plan is inconsistent.");
    }
    if (!restorePlan.includesAppGroups && planItems.count != 0) {
        return PXAppGroupRestoreTargetPlanFail(error,
                                               PXAppGroupRestoreTargetPlanErrorInconsistentPlan,
                                               @"$.appGroups",
                                               @"The accepted App Group restore plan is inconsistent.");
    }
    if (planItems.count > PXAppGroupRestoreTargetPlanMaximumPlannedItems) {
        return PXAppGroupRestoreTargetPlanFail(error,
                                               PXAppGroupRestoreTargetPlanErrorLimitExceeded,
                                               @"$.appGroups",
                                               @"The App Group restore target-plan item limit was exceeded.");
    }
    if (entitledGroupIdentifiers.count > PXAppGroupRestoreTargetPlanMaximumEntitlements) {
        return PXAppGroupRestoreTargetPlanFail(error,
                                               PXAppGroupRestoreTargetPlanErrorLimitExceeded,
                                               @"$.entitlements",
                                               @"The signed App Group entitlement limit was exceeded.");
    }

    NSMutableSet<NSString *> *entitlementSet =
        [NSMutableSet setWithCapacity:entitledGroupIdentifiers.count];
    for (NSUInteger index = 0; index < entitledGroupIdentifiers.count; index++) {
        id candidate = entitledGroupIdentifiers[index];
        NSString *fieldPath = [NSString stringWithFormat:@"$.entitlements[%lu]",
                               (unsigned long)index];
        if (![candidate isKindOfClass:[NSString class]] ||
            [(NSString *)candidate length] == 0 ||
            !PXAppGroupRestoreTargetPlanStringHasNonWhitespaceText((NSString *)candidate) ||
            PXAppGroupRestoreTargetPlanStringContainsNUL((NSString *)candidate) ||
            [entitlementSet containsObject:(NSString *)candidate]) {
            return PXAppGroupRestoreTargetPlanFail(error,
                                                   PXAppGroupRestoreTargetPlanErrorInvalidEntitlementSet,
                                                   fieldPath,
                                                   @"The signed App Group entitlement set is invalid.");
        }
        [entitlementSet addObject:[(NSString *)candidate copy]];
    }

    AppGroupContainerResolver *resolver = [[AppGroupContainerResolver alloc] init];
    PXDestructivePathValidator *validator = [[PXDestructivePathValidator alloc] init];
    NSMutableSet<NSString *> *plannedGroupIdentifiers = [NSMutableSet setWithCapacity:planItems.count];
    NSMutableDictionary<NSString *, PXAppGroupRestoreTargetBuilder *> *builderByCanonicalPath =
        [NSMutableDictionary dictionaryWithCapacity:planItems.count];
    NSMutableArray<PXAppGroupRestoreTargetBuilder *> *builderOrder =
        [NSMutableArray arrayWithCapacity:planItems.count];

    for (NSUInteger index = 0; index < planItems.count; index++) {
        id candidate = planItems[index];
        NSString *itemFieldPath = [NSString stringWithFormat:@"$.appGroups[%lu]",
                                   (unsigned long)index];
        NSString *identifierFieldPath = [itemFieldPath stringByAppendingString:@".groupIdentifier"];
        NSString *destinationFieldPath = [itemFieldPath stringByAppendingString:@".destination"];

        if (![candidate isKindOfClass:[PXRestorePlanAppGroupItem class]]) {
            return PXAppGroupRestoreTargetPlanFail(error,
                                                   PXAppGroupRestoreTargetPlanErrorInconsistentPlan,
                                                   itemFieldPath,
                                                   @"The accepted App Group restore plan is inconsistent.");
        }

        PXRestorePlanAppGroupItem *planItem = (PXRestorePlanAppGroupItem *)candidate;
        NSString *groupIdentifier = planItem.groupIdentifier;
        if (!PXAppGroupRestoreTargetPlanBasicStringIsValid(groupIdentifier)) {
            return PXAppGroupRestoreTargetPlanFail(error,
                                                   PXAppGroupRestoreTargetPlanErrorInconsistentPlan,
                                                   identifierFieldPath,
                                                   @"The accepted App Group restore plan is inconsistent.");
        }
        if (!PXAppGroupRestoreTargetPlanBasicStringIsValid(planItem.archiveName) ||
            !PXAppGroupRestoreTargetPlanBasicStringIsValid(planItem.sourcePath)) {
            return PXAppGroupRestoreTargetPlanFail(error,
                                                   PXAppGroupRestoreTargetPlanErrorInconsistentPlan,
                                                   itemFieldPath,
                                                   @"The accepted App Group restore plan is inconsistent.");
        }
        if ([plannedGroupIdentifiers containsObject:groupIdentifier]) {
            return PXAppGroupRestoreTargetPlanFail(error,
                                                   PXAppGroupRestoreTargetPlanErrorInconsistentPlan,
                                                   identifierFieldPath,
                                                   @"The accepted App Group restore plan contains a duplicate identity.");
        }
        [plannedGroupIdentifiers addObject:[groupIdentifier copy]];

        if (![entitlementSet containsObject:groupIdentifier]) {
            return PXAppGroupRestoreTargetPlanFail(error,
                                                   PXAppGroupRestoreTargetPlanErrorUnentitledGroup,
                                                   identifierFieldPath,
                                                   @"A planned App Group is not authorized by the signed entitlement set.");
        }

        NSError *rootfulResolverError = nil;
        PXResolvedContainer *rootfulModel =
            [resolver resolveAppGroupContainerForGroupIdentifier:groupIdentifier
                                                            root:PXResolvedContainerRootRootful
                                                           error:&rootfulResolverError];
        if (rootfulResolverError) {
            return PXAppGroupRestoreTargetPlanFail(error,
                                                   PXAppGroupRestoreTargetPlanErrorResolverFailed,
                                                   destinationFieldPath,
                                                   @"An exact App Group restore target could not be resolved safely.");
        }

        NSError *rootlessResolverError = nil;
        PXResolvedContainer *rootlessModel =
            [resolver resolveAppGroupContainerForGroupIdentifier:groupIdentifier
                                                            root:PXResolvedContainerRootRootless
                                                           error:&rootlessResolverError];
        if (rootlessResolverError) {
            return PXAppGroupRestoreTargetPlanFail(error,
                                                   PXAppGroupRestoreTargetPlanErrorResolverFailed,
                                                   destinationFieldPath,
                                                   @"An exact App Group restore target could not be resolved safely.");
        }

        NSMutableArray<PXResolvedContainer *> *models = [NSMutableArray arrayWithCapacity:2];
        NSMutableArray<NSString *> *canonicalPaths = [NSMutableArray arrayWithCapacity:2];
        if (rootfulModel) {
            NSError *validationError = nil;
            NSString *canonicalPath =
                [validator validatedCanonicalPathForContainer:rootfulModel error:&validationError];
            if (validationError ||
                ![canonicalPath isKindOfClass:[NSString class]] ||
                canonicalPath.length == 0) {
                return PXAppGroupRestoreTargetPlanFail(error,
                                                       PXAppGroupRestoreTargetPlanErrorValidatorFailed,
                                                       destinationFieldPath,
                                                       @"An exact App Group restore target failed canonical validation.");
            }
            [models addObject:rootfulModel];
            [canonicalPaths addObject:[canonicalPath copy]];
        }
        if (rootlessModel) {
            NSError *validationError = nil;
            NSString *canonicalPath =
                [validator validatedCanonicalPathForContainer:rootlessModel error:&validationError];
            if (validationError ||
                ![canonicalPath isKindOfClass:[NSString class]] ||
                canonicalPath.length == 0) {
                return PXAppGroupRestoreTargetPlanFail(error,
                                                       PXAppGroupRestoreTargetPlanErrorValidatorFailed,
                                                       destinationFieldPath,
                                                       @"An exact App Group restore target failed canonical validation.");
            }
            [models addObject:rootlessModel];
            [canonicalPaths addObject:[canonicalPath copy]];
        }

        if (models.count == 0) {
            return PXAppGroupRestoreTargetPlanFail(error,
                                                   PXAppGroupRestoreTargetPlanErrorMissingTarget,
                                                   destinationFieldPath,
                                                   @"An exact App Group restore target is missing.");
        }

        NSString *canonicalPath = canonicalPaths.firstObject;
        if (canonicalPaths.count == 2 &&
            ![canonicalPaths[0] isEqualToString:canonicalPaths[1]]) {
            return PXAppGroupRestoreTargetPlanFail(error,
                                                   PXAppGroupRestoreTargetPlanErrorAmbiguousTarget,
                                                   destinationFieldPath,
                                                   @"The exact App Group restore target is ambiguous.");
        }

        PXAppGroupRestoreTargetBuilder *builder = builderByCanonicalPath[canonicalPath];
        if (!builder) {
            if (builderOrder.count >= PXAppGroupRestoreTargetPlanMaximumTargets) {
                return PXAppGroupRestoreTargetPlanFail(error,
                                                       PXAppGroupRestoreTargetPlanErrorLimitExceeded,
                                                       @"$.appGroups",
                                                       @"The App Group physical-target limit was exceeded.");
            }
            builder = [[PXAppGroupRestoreTargetBuilder alloc] init];
            builder.canonicalPath = [canonicalPath copy];
            builder.groupIdentifiers = [NSMutableArray array];
            builder.containerModels = [NSMutableArray array];
            builder.planItems = [NSMutableArray array];
            builderByCanonicalPath[builder.canonicalPath] = builder;
            [builderOrder addObject:builder];
        }

        [builder.groupIdentifiers addObject:[groupIdentifier copy]];
        [builder.containerModels addObjectsFromArray:models];
        [builder.planItems addObject:planItem];
    }

    NSMutableArray<PXAppGroupRestoreTarget *> *targets =
        [NSMutableArray arrayWithCapacity:builderOrder.count];
    NSMutableDictionary<NSString *, PXAppGroupRestoreTarget *> *lookup =
        [NSMutableDictionary dictionaryWithCapacity:planItems.count];

    for (PXAppGroupRestoreTargetBuilder *builder in builderOrder) {
        PXAppGroupRestoreTarget *target =
            [[PXAppGroupRestoreTarget alloc] initWithGroupIdentifiers:builder.groupIdentifiers
                                                     containerModels:builder.containerModels
                                                       canonicalPath:builder.canonicalPath
                                                           planItems:builder.planItems];
        if (!target) {
            return PXAppGroupRestoreTargetPlanFail(error,
                                                   PXAppGroupRestoreTargetPlanErrorInconsistentPlan,
                                                   @"$.appGroups",
                                                   @"The App Group restore target plan could not be represented safely.");
        }
        [targets addObject:target];
        for (NSString *groupIdentifier in target.groupIdentifiers) {
            lookup[groupIdentifier] = target;
        }
    }

    return [[PXAppGroupRestoreTargetPlan alloc] initWithTargets:targets
                                        targetByGroupIdentifier:lookup];
}

- (PXAppGroupRestoreTarget *)targetForGroupIdentifier:(NSString *)groupIdentifier {
    if (![groupIdentifier isKindOfClass:[NSString class]] || groupIdentifier.length == 0) {
        return nil;
    }
    return self.targetByGroupIdentifier[groupIdentifier];
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

@end
