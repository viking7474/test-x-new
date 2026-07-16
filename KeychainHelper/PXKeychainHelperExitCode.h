#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PXKeychainHelperExitCode) {
    PXKeychainHelperExitCodeCompleted = 0,
    PXKeychainHelperExitCodePartial = 10,
    PXKeychainHelperExitCodeInvalidArguments = 20,
    PXKeychainHelperExitCodeInvalidInput = 21,
    PXKeychainHelperExitCodeAccessDenied = 30,
    PXKeychainHelperExitCodeOperationFailed = 40,
    PXKeychainHelperExitCodeProtocolFailure = 50,
    PXKeychainHelperExitCodeHelperUnavailable = 60,
    PXKeychainHelperExitCodeTargetUnavailable = 61,
    PXKeychainHelperExitCodeEntitlementFailure = 62,
    PXKeychainHelperExitCodeWorkspaceFailure = 63,
    PXKeychainHelperExitCodeSigningFailure = 64,
    PXKeychainHelperExitCodeDependencyUnavailable = 65,
};

NS_ASSUME_NONNULL_END
