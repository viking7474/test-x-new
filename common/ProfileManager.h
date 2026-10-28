#import <Foundation/Foundation.h>

@class Profile;

NS_ASSUME_NONNULL_BEGIN

@interface Profile : NSObject <NSSecureCoding>

@property (nonatomic, strong, readonly) NSString *profileId;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *shortDescription;
@property (nonatomic, strong) NSString *iconName;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong) NSDate *lastUsed;
@property (nonatomic, strong) NSDictionary *settings;

- (instancetype)initWithName:(NSString *)name iconName:(NSString *)iconName;
- (instancetype)initWithName:(NSString *)name shortDescription:(NSString *)shortDescription iconName:(NSString *)iconName;
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)toDictionary;

@end

@interface ProfileManager : NSObject

@property (nonatomic, strong, readonly) NSArray<Profile *> *profiles;
@property (nonatomic, strong, readonly, nullable) Profile *currentProfile;

+ (instancetype)sharedManager;

// Completion runs on main; activation follows committed generation and metadata.
// ID/timestamps are assigned to the caller as before, then create owns a secure
// detached model. Later caller edits are not edits of that pending operation.
// Activation rechecks model values against the saved registry around callbacks;
// an already registered inactive candidate may remain when that check fails.
// Failure may leave inactive artifacts or a ready registered profile for recovery.
- (void)createProfile:(Profile *)profile completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
// Display plist group commits before registry archive. Failure after that commit
// can leave new display metadata with the previous registry; reload/retry is
// explicit. Manager slot adoption/notification require registry persistence;
// caller mutations of an already shared Profile object cannot be undone here.
// Proposed registry bytes must pass the load-time decoder before display writes;
// secure coding alone does not validate typed fields or unique profile IDs.
- (void)updateProfile:(Profile *)profile completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
// Edit a registered profile by ID using an owned candidate; nil fields keep
// registered values. Active labels commit after registry persistence.
// A later selection conflict can return failure after metadata was saved; reload
// before retrying. Completion runs on main after lifecycle ownership is released.
- (void)editProfileID:(NSString *)profileID name:(NSString * _Nullable)name shortDescription:(NSString * _Nullable)shortDescription completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
// Active deletion selects a valid fallback before unregistering/removing files.
// Encoding fails before activation. An I/O failure after the journal decision
// commits leaves recovery pending; reload completes/cancels it from known state.
- (void)deleteProfile:(Profile *)profile completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
// UI deletion rechecks committed active selection under lifecycle ownership.
// Success acknowledges logical unregistering; best-effort file cleanup may remain.
- (void)deleteInactiveProfileID:(NSString *)profileID completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
// Capture registered IDs once, preserving 0/profile_0; recheck each active target.
// Main-thread result contains immutable deleted/skipped ID arrays, failed ID->
// message dictionary and error string. One attempt per ID; no orphan enumeration.
- (void)deleteInactiveProfilesWithCompletion:(void (^)(NSDictionary *result))completion;
// Resolve the registered record by ID; alias object fields are not authoritative.
- (void)switchToProfile:(Profile *)profile completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)loadProfilesWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion;

// New methods to manage central profile information
- (void)updateCurrentProfileInfoWithProfile:(Profile *)profile;
- (BOOL)updateCurrentProfileInfoWithProfile:(Profile *)profile error:(NSError * _Nullable * _Nullable)error;
- (BOOL)refreshCurrentProfileFromCommittedSelectionWithError:(NSError * _Nullable * _Nullable)error;
- (Profile *)loadCurrentProfileInfoFromCentralStore;
- (BOOL)saveCentralProfileInfo:(NSDictionary *)infoDict;
- (NSDictionary *)loadCentralProfileInfo;
- (NSString *)centralProfileInfoPath;

// Convenience methods for ProfileManagerViewController
- (void)removeProfile:(NSString *)profileName;
- (void)renameProfile:(NSString *)oldName to:(NSString *)newName;
- (void)addProfile:(NSString *)profileName;
- (void)addProfileWithName:(NSString *)profileName shortDescription:(NSString *)shortDescription;

// Profile ID generation
// Read-only candidates, not reservations. Errors/exhaustion return nil; create
// still reserves exclusively. ASCII numbers and A01..Z99 define ordering; other
// custom IDs stay valid. Requires main; unreadable sources never get a fallback ID.
- (nullable NSString *)generateProfileID;
- (nullable NSString *)generateProfileIDWithError:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
