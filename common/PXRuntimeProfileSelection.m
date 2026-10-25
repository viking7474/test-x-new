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

NSDictionary *PXReadRuntimeProfileSelection(PXRuntimeSourceTransaction *tx, NSString *centralPath, NSString *legacyPath, NSError **error) {
    NSMutableDictionary *records = [NSMutableDictionary dictionary];
    for (NSString *path in @[centralPath, legacyPath]) {
        BOOL exists = NO;
        NSDictionary *info = [tx dictionaryAtPath:path exists:&exists error:error];
        if (!info) return nil;
        records[path] = @{ @"exists": @(exists), @"info": info };
    }
    return [records copy];
}

BOOL PXRuntimeProfileSelectionMatches(PXRuntimeSourceTransaction *tx, NSDictionary *expected, NSString *centralPath, NSString *legacyPath, NSError **error) {
    NSDictionary *current = PXReadRuntimeProfileSelection(tx, centralPath, legacyPath, error);
    if (!current) return NO;
    if (![expected isKindOfClass:NSDictionary.class] || ![current isEqual:expected]) {
        if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:20
            userInfo:@{NSLocalizedDescriptionKey: @"Profile selection changed; retry operation"}];
        return NO;
    }
    return YES;
}

BOOL PXStageRuntimeProfileSelectionIfUnchanged(PXRuntimeSourceTransaction *tx, NSDictionary *info, NSDictionary *expected,
    NSString *centralPath, NSString *legacyPath, NSError **error) {
    return PXRuntimeProfileSelectionMatches(tx, expected, centralPath, legacyPath, error) &&
        PXStageRuntimeProfileSelection(tx, info, centralPath, legacyPath, error);
}
