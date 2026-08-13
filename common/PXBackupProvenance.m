#import "PXBackupProvenance.h"
#import "PXBackupAuthenticatedEnvelope.h"

static NSString *PXProvenanceString(id value) {
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed.length ? trimmed : nil;
}

NSDictionary<NSString *, id> *PXCreateBackupProvenance(NSString *bundleIdentifier,
                                                        NSString *profileIdentifier,
                                                        NSNumber *profileGeneration,
                                                        NSString *selectedScope,
                                                        NSString *encryptionAlgorithm,
                                                        NSString *externalKeyIdentifier) {
    NSString *bundle = PXProvenanceString(bundleIdentifier);
    NSString *profile = PXProvenanceString(profileIdentifier);
    NSString *scope = PXProvenanceString(selectedScope);
    NSString *algorithm = PXProvenanceString(encryptionAlgorithm);
    NSString *keyID = PXProvenanceString(externalKeyIdentifier);
    if (!bundle || !profile || !scope || !keyID ||
        ![profileGeneration isKindOfClass:[NSNumber class]] || profileGeneration.unsignedLongLongValue == 0 ||
        ![algorithm isEqualToString:PXBackupAuthenticatedEnvelopeAlgorithm]) return nil;
    if ([keyID.lowercaseString containsString:@"key="] || [keyID.lowercaseString containsString:@"secret"]) return nil;
    return @{
        @"schema": @"tlinkios.backup-provenance.v1",
        @"sourceBundleID": bundle,
        @"profileID": profile,
        @"profileGeneration": profileGeneration,
        @"selectedScope": scope,
        @"encryption": @{
            @"algorithm": algorithm,
            @"keyIdentifier": keyID,
            @"keyMaterialStored": @NO,
        },
    };
}

BOOL PXBackupProvenanceMatchesRestoreContext(NSDictionary<NSString *, id> *provenance,
                                             NSString *bundleIdentifier,
                                             NSString *profileIdentifier,
                                             NSNumber *profileGeneration,
                                             NSString *selectedScope) {
    if (![provenance isKindOfClass:[NSDictionary class]] ||
        ![provenance[@"schema"] isEqual:@"tlinkios.backup-provenance.v1"]) return NO;
    NSDictionary *encryption = [provenance[@"encryption"] isKindOfClass:[NSDictionary class]] ? provenance[@"encryption"] : nil;
    return [provenance[@"sourceBundleID"] isEqual:bundleIdentifier] &&
           [provenance[@"profileID"] isEqual:profileIdentifier] &&
           [provenance[@"profileGeneration"] isEqual:profileGeneration] &&
           [provenance[@"selectedScope"] isEqual:selectedScope] &&
           [encryption[@"algorithm"] isEqual:PXBackupAuthenticatedEnvelopeAlgorithm] &&
           [encryption[@"keyMaterialStored"] isEqual:@NO] &&
           PXProvenanceString(encryption[@"keyIdentifier"]) != nil;
}

NSData *PXBackupProvenanceAssociatedData(NSDictionary<NSString *, id> *provenance) {
    if (![provenance isKindOfClass:[NSDictionary class]]) return [NSData data];
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:provenance options:NSJSONWritingSortedKeys error:&error];
    return error ? [NSData data] : data;
}
