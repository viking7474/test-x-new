//
//  WeaponXToast.h
//  ProjectX
//
//  P1: unified toast presenter. Replaces the duplicated inline toast
//  implementations in TabBarController and AppVersionSpoofingViewController.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WeaponXToast : NSObject

/// Show a toast anchored to the top of the key window.
+ (void)showMessage:(NSString *)message isSuccess:(BOOL)isSuccess;
+ (void)showMessage:(NSString *)message isSuccess:(BOOL)isSuccess duration:(CGFloat)duration;

/// Show a toast inside a specific view (for modally presented screens).
+ (void)showMessage:(NSString *)message isSuccess:(BOOL)isSuccess inView:(UIView *)view;

@end

NS_ASSUME_NONNULL_END
