#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const PXBackupAuthenticatedEnvelopeErrorDomain;
FOUNDATION_EXPORT NSString * const PXBackupAuthenticatedEnvelopeAlgorithm;

/// Encrypt-then-MAC envelope. The caller owns the 64-byte external key and must
/// resolve it from protected storage; key material is never serialized.
FOUNDATION_EXPORT nullable NSData *PXSealBackupPayload(NSData *plaintext,
                                                       NSData *associatedData,
                                                       NSData *externalKey,
                                                       NSString *keyIdentifier,
                                                       NSError **error);

/// Verifies the authentication tag in constant time before decrypting.
FOUNDATION_EXPORT nullable NSData *PXOpenBackupPayload(NSData *envelope,
                                                       NSData *associatedData,
                                                       NSData *externalKey,
                                                       NSString *expectedKeyIdentifier,
                                                       NSError **error);

NS_ASSUME_NONNULL_END
