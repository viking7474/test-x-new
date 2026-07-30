#import "PXBackupAuthenticatedEnvelope.h"
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>
#import <Security/Security.h>

NSErrorDomain const PXBackupAuthenticatedEnvelopeErrorDomain = @"com.hydra.projectx.backup-envelope";
NSString * const PXBackupAuthenticatedEnvelopeAlgorithm = @"AES-256-CBC+HMAC-SHA256";

static BOOL PXEnvelopeFail(NSError **error, NSInteger code, NSString *message) {
    if (error) *error = [NSError errorWithDomain:PXBackupAuthenticatedEnvelopeErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: message}];
    return NO;
}

static NSString *PXEnvelopeString(id value) {
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed.length ? trimmed : nil;
}

static void PXAppendLengthPrefixed(NSMutableData *output, NSData *value) {
    uint64_t length = CFSwapInt64HostToBig((uint64_t)value.length);
    [output appendBytes:&length length:sizeof(length)];
    [output appendData:value];
}

static NSData *PXEnvelopeMACInput(NSString *keyID, NSData *iv, NSData *ciphertext, NSData *aad) {
    NSMutableData *input = [NSMutableData data];
    for (NSData *part in @[
        [@"PXBAE1" dataUsingEncoding:NSUTF8StringEncoding],
        [PXBackupAuthenticatedEnvelopeAlgorithm dataUsingEncoding:NSUTF8StringEncoding],
        [keyID dataUsingEncoding:NSUTF8StringEncoding], iv, ciphertext, aad ?: [NSData data]
    ]) PXAppendLengthPrefixed(input, part);
    return input;
}

static NSData *PXHMAC(NSData *key, NSData *input) {
    unsigned char output[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, key.bytes, key.length, input.bytes, input.length, output);
    return [NSData dataWithBytes:output length:sizeof(output)];
}

static BOOL PXConstantTimeEqual(NSData *left, NSData *right) {
    if (![left isKindOfClass:[NSData class]] || ![right isKindOfClass:[NSData class]] || left.length != right.length) return NO;
    const uint8_t *a = left.bytes, *b = right.bytes;
    uint8_t difference = 0;
    for (NSUInteger index = 0; index < left.length; index++) difference |= a[index] ^ b[index];
    return difference == 0;
}

static NSData *PXCrypt(CCOperation operation, NSData *input, NSData *key, NSData *iv, NSError **error) {
    size_t capacity = input.length + kCCBlockSizeAES128;
    NSMutableData *output = [NSMutableData dataWithLength:capacity];
    size_t written = 0;
    CCCryptorStatus status = CCCrypt(operation, kCCAlgorithmAES, kCCOptionPKCS7Padding,
                                     key.bytes, key.length, iv.bytes,
                                     input.bytes, input.length, output.mutableBytes, capacity, &written);
    if (status != kCCSuccess) {
        PXEnvelopeFail(error, 4, @"Authenticated-envelope cryptographic operation failed");
        return nil;
    }
    output.length = written;
    return output;
}

NSData *PXSealBackupPayload(NSData *plaintext, NSData *associatedData, NSData *externalKey,
                            NSString *keyIdentifier, NSError **error) {
    if (error) *error = nil;
    NSString *keyID = PXEnvelopeString(keyIdentifier);
    if (![plaintext isKindOfClass:[NSData class]] || ![associatedData isKindOfClass:[NSData class]] ||
        externalKey.length != 64 || !keyID) {
        PXEnvelopeFail(error, 1, @"Envelope input or external key is invalid");
        return nil;
    }
    NSMutableData *iv = [NSMutableData dataWithLength:kCCBlockSizeAES128];
    if (SecRandomCopyBytes(kSecRandomDefault, iv.length, iv.mutableBytes) != errSecSuccess) {
        PXEnvelopeFail(error, 2, @"A secure envelope IV could not be generated");
        return nil;
    }
    NSData *encryptionKey = [externalKey subdataWithRange:NSMakeRange(0, 32)];
    NSData *macKey = [externalKey subdataWithRange:NSMakeRange(32, 32)];
    NSData *ciphertext = PXCrypt(kCCEncrypt, plaintext, encryptionKey, iv, error);
    if (!ciphertext) return nil;
    NSData *tag = PXHMAC(macKey, PXEnvelopeMACInput(keyID, iv, ciphertext, associatedData));
    NSDictionary *representation = @{
        @"format": @"projectx.authenticated-envelope.v1",
        @"algorithm": PXBackupAuthenticatedEnvelopeAlgorithm,
        @"keyIdentifier": keyID,
        @"iv": iv,
        @"ciphertext": ciphertext,
        @"authenticationTag": tag,
    };
    NSData *serialized = [NSPropertyListSerialization dataWithPropertyList:representation format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];
    if (!serialized && error && !*error) PXEnvelopeFail(error, 3, @"Envelope serialization failed");
    return serialized;
}

NSData *PXOpenBackupPayload(NSData *envelope, NSData *associatedData, NSData *externalKey,
                            NSString *expectedKeyIdentifier, NSError **error) {
    if (error) *error = nil;
    NSString *expectedKeyID = PXEnvelopeString(expectedKeyIdentifier);
    if (![envelope isKindOfClass:[NSData class]] || ![associatedData isKindOfClass:[NSData class]] ||
        externalKey.length != 64 || !expectedKeyID) {
        PXEnvelopeFail(error, 1, @"Envelope input or external key is invalid");
        return nil;
    }
    id object = [NSPropertyListSerialization propertyListWithData:envelope options:NSPropertyListImmutable format:nil error:error];
    NSDictionary *representation = [object isKindOfClass:[NSDictionary class]] ? object : nil;
    NSSet *expectedKeys = [NSSet setWithArray:@[@"format", @"algorithm", @"keyIdentifier", @"iv", @"ciphertext", @"authenticationTag"]];
    if (!representation || ![[NSSet setWithArray:representation.allKeys] isEqual:expectedKeys] ||
        ![representation[@"format"] isEqual:@"projectx.authenticated-envelope.v1"] ||
        ![representation[@"algorithm"] isEqual:PXBackupAuthenticatedEnvelopeAlgorithm] ||
        ![representation[@"keyIdentifier"] isEqual:expectedKeyID] ||
        ![representation[@"iv"] isKindOfClass:[NSData class]] || [representation[@"iv"] length] != kCCBlockSizeAES128 ||
        ![representation[@"ciphertext"] isKindOfClass:[NSData class]] ||
        ![representation[@"authenticationTag"] isKindOfClass:[NSData class]]) {
        PXEnvelopeFail(error, 3, @"Envelope metadata or key identifier is invalid");
        return nil;
    }
    NSData *macKey = [externalKey subdataWithRange:NSMakeRange(32, 32)];
    NSData *expectedTag = PXHMAC(macKey, PXEnvelopeMACInput(expectedKeyID, representation[@"iv"], representation[@"ciphertext"], associatedData));
    if (!PXConstantTimeEqual(expectedTag, representation[@"authenticationTag"])) {
        PXEnvelopeFail(error, 5, @"Envelope authentication failed");
        return nil;
    }
    NSData *encryptionKey = [externalKey subdataWithRange:NSMakeRange(0, 32)];
    return PXCrypt(kCCDecrypt, representation[@"ciphertext"], encryptionKey, representation[@"iv"], error);
}
