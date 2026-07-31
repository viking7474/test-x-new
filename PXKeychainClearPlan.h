#import <Foundation/Foundation.h>

@interface PXKeychainClearPlan : NSObject {
@private
    NSString *_bundleIdentifier;
    BOOL _enabled;
    BOOL _systemApplication;
    BOOL _systemPolicyAllowed;
    NSArray<NSString *> *_selectedGroups;
    NSArray<NSString *> *_authorizedGroups;
    NSString *_applicationIdentifier;
    NSUInteger _plannedPassCount;
    NSString *_skipDetail;
    NSInteger _planningFailureCode;
    NSString *_planningFailureMessage;
}
@property (nonatomic, copy, readonly) NSString *bundleIdentifier;
@property (nonatomic, assign, readonly, getter=isEnabled) BOOL enabled;
@property (nonatomic, assign, readonly, getter=isSystemApplication) BOOL systemApplication;
@property (nonatomic, assign, readonly, getter=isSystemPolicyAllowed) BOOL systemPolicyAllowed;
@property (nonatomic, copy, readonly) NSArray<NSString *> *selectedGroups;
@property (nonatomic, copy, readonly) NSArray<NSString *> *authorizedGroups;
@property (nonatomic, copy, readonly) NSString *applicationIdentifier;
@property (nonatomic, assign, readonly) NSUInteger plannedPassCount;
@property (nonatomic, copy, readonly) NSString *skipDetail;
@property (nonatomic, assign, readonly) NSInteger planningFailureCode;
@property (nonatomic, copy, readonly) NSString *planningFailureMessage;
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
                  planningFailureMessage:(NSString *)planningFailureMessage;
@end
