#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Modern RRS manager (list / multi-select delete with confirm / detail / sequence sheet).
/// Callback contracts match the previous inline controller used by ProjectXViewController.
@interface PXRRSManagerViewController : UITableViewController

@property (nonatomic, copy) NSArray<NSDictionary *> *entries;
@property (nonatomic, assign) NSInteger nextIndex;
/// 0 = oldest→newest, 1 = newest→oldest, 2 = by begin/end range
@property (nonatomic, assign) NSInteger sequenceMode;
@property (nonatomic, assign) NSInteger rangeBegin; // 1-based; 0 = unset
@property (nonatomic, assign) NSInteger rangeEnd;   // 1-based exclusive end; 0 = unset

@property (nonatomic, copy, nullable) void (^onDelete)(NSArray<NSString *> *dirs);
@property (nonatomic, copy, nullable) void (^onSaveAndRestore)(NSString *backupDir);
@property (nonatomic, copy, nullable) void (^onSequenceChanged)(NSInteger mode, NSInteger begin, NSInteger end);
@property (nonatomic, copy, nullable) void (^onNextChanged)(NSInteger nextIndex);
@property (nonatomic, copy, nullable) NSArray<NSDictionary *> *(^onReload)(void);

@end

NS_ASSUME_NONNULL_END
