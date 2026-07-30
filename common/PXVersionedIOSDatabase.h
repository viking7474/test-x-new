#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const PXVersionedIOSDatabaseErrorDomain;
FOUNDATION_EXPORT NSInteger const PXVersionedIOSDatabaseReaderVersion;

/// Loads the iOS build/model JSON files as one versioned, immutable publication.
///
/// Preferred manifest (`ios_database_manifest.json`, schema v1):
/// {
///   "schemaVersion": 1,
///   "databaseVersion": "2026.07.1",
///   "minimumReaderVersion": 1,
///   "generatedAt": "2026-07-30T00:00:00Z",
///   "files": {
///     "iosBuildDB": {"path": "ios/2026.07.1/ios_build_db.json", "sha256": "..."},
///     "iphoneModelDB": {"path": "ios/2026.07.1/iphone_model_db.json", "sha256": "..."}
///   }
/// }
///
/// Both files are parsed and validated before either one is published. When no
/// manifest exists, the legacy top-level files remain readable as `legacy-v1`.
@interface PXVersionedIOSDatabase : NSObject

+ (instancetype)sharedDatabase;

- (BOOL)loadIfNeeded:(NSError * _Nullable * _Nullable)error;
- (NSDictionary * _Nullable)rootForKey:(NSString *)key
                                  error:(NSError * _Nullable * _Nullable)error;

@property (nonatomic, copy, readonly, nullable) NSString *databaseVersion;
@property (nonatomic, copy, readonly, nullable) NSString *sourcePath;
@property (nonatomic, copy, readonly) NSDictionary *metadata;
@property (nonatomic, readonly, getter=isLegacy) BOOL legacy;

/// Reloads a complete candidate and keeps the last-known-good publication on failure.
- (BOOL)reload:(NSError * _Nullable * _Nullable)error;

/// Drops the publication. The next query reloads a complete database set.
- (void)invalidate;

@end

NS_ASSUME_NONNULL_END
