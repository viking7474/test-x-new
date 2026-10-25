#import "PXRuntimeProfileSelection.h"
#import "PXPaths.h"

BOOL PXStageRuntimeProfileSelection(PXRuntimeSourceTransaction *tx, NSDictionary *info,
    NSString *centralPath, NSString *legacyPath, NSError **error) {
    if (![info isKindOfClass:NSDictionary.class] || ![info[@"ProfileId"] isKindOfClass:NSString.class] ||
        ![PXValidatedProfileID(info[@"ProfileId"]) isEqualToString:info[@"ProfileId"]]) {
        if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:10
            userInfo:@{NSLocalizedDescriptionKey: @"Invalid profile selection record"}];
        return NO;
    }
    return [tx setDictionary:info atPath:centralPath error:error] &&
        [tx setDictionary:info atPath:legacyPath error:error];
}
