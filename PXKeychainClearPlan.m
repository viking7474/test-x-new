#import "PXKeychainClearPlan.h"

@implementation PXKeychainClearPlan
@synthesize bundleIdentifier = _bundleIdentifier;
@synthesize enabled = _enabled;
@synthesize systemApplication = _systemApplication;
@synthesize systemPolicyAllowed = _systemPolicyAllowed;
@synthesize selectedGroups = _selectedGroups;
@synthesize authorizedGroups = _authorizedGroups;
@synthesize applicationIdentifier = _applicationIdentifier;
@synthesize plannedPassCount = _plannedPassCount;
@synthesize skipDetail = _skipDetail;
@synthesize planningFailureCode = _planningFailureCode;
@synthesize planningFailureMessage = _planningFailureMessage;
- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                                 enabled:(BOOL)enabled
                       systemApplication:(BOOL)systemApplication
                     systemPolicyAllowed:(BOOL)systemPolicyAllowed
                          selectedGroups:(NSArray<NSString *> *)selectedGroups
                        authorizedGroups:(NSArray<NSString *> *)authorizedGroups
                   applicationIdentifier:(NSString *)applicationIdentifier
                        plannedPassCount:(NSUInteger)plannedPassCount
                              skipDetail:(NSString *)skipDetail
                     planningFailureCode:(NSInteger)planningFailureCode
                  planningFailureMessage:(NSString *)planningFailureMessage {
    self = [super init];
    if (self) {
        _bundleIdentifier = [bundleIdentifier copy] ?: @"";
        _enabled = enabled;
        _systemApplication = systemApplication;
        _systemPolicyAllowed = systemPolicyAllowed;
        _selectedGroups = [selectedGroups copy] ?: @[];
        _authorizedGroups = [authorizedGroups copy] ?: @[];
        _applicationIdentifier = [applicationIdentifier copy];
        _plannedPassCount = plannedPassCount;
        _skipDetail = [skipDetail copy];
        _planningFailureCode = planningFailureCode;
        _planningFailureMessage = [planningFailureMessage copy];
    }
    return self;
}
@end
