#import "PXUIKitCompat.h"

static id PXCallObject0(id target, SEL selector) {
    if (!target || !selector || ![target respondsToSelector:selector]) return nil;
    IMP imp = [target methodForSelector:selector];
    id (*fn)(id, SEL) = (void *)imp;
    return fn(target, selector);
}

static id PXCallObject1(id target, SEL selector, id argument) {
    if (!target || !selector || ![target respondsToSelector:selector]) return nil;
    IMP imp = [target methodForSelector:selector];
    id (*fn)(id, SEL, id) = (void *)imp;
    return fn(target, selector, argument);
}

static NSInteger PXCallInteger0(id target, SEL selector, NSInteger fallback) {
    if (!target || !selector || ![target respondsToSelector:selector]) return fallback;
    IMP imp = [target methodForSelector:selector];
    NSInteger (*fn)(id, SEL) = (void *)imp;
    return fn(target, selector);
}

static BOOL PXUIKitHasIOS13Features(void) {
    return [UIColor respondsToSelector:NSSelectorFromString(@"labelColor")];
}

static UIColor *PXColorFromClassSelector(NSString *selectorName, UIColor *fallback) {
    UIColor *color = PXCallObject0(UIColor.class, NSSelectorFromString(selectorName));
    return [color isKindOfClass:UIColor.class] ? color : fallback;
}

UIColor *PXLabelColor(void) {
    return PXColorFromClassSelector(@"labelColor", [UIColor blackColor]);
}

UIColor *PXSecondaryLabelColor(void) {
    return PXColorFromClassSelector(@"secondaryLabelColor", [UIColor darkGrayColor]);
}

UIColor *PXTertiaryLabelColor(void) {
    return PXColorFromClassSelector(@"tertiaryLabelColor", [UIColor grayColor]);
}

UIColor *PXSeparatorColor(void) {
    return PXColorFromClassSelector(@"separatorColor", [UIColor colorWithWhite:0.82 alpha:1.0]);
}

UIColor *PXSystemBackgroundColor(void) {
    return PXColorFromClassSelector(@"systemBackgroundColor", [UIColor whiteColor]);
}

UIColor *PXSecondarySystemGroupedBackgroundColor(void) {
    return PXColorFromClassSelector(@"secondarySystemGroupedBackgroundColor", [UIColor whiteColor]);
}

UIColor *PXTertiarySystemGroupedBackgroundColor(void) {
    return PXColorFromClassSelector(@"tertiarySystemGroupedBackgroundColor", [UIColor colorWithWhite:0.97 alpha:1.0]);
}

UIColor *PXSecondarySystemBackgroundColor(void) {
    return PXColorFromClassSelector(@"secondarySystemBackgroundColor", [UIColor colorWithWhite:0.96 alpha:1.0]);
}

UIColor *PXTertiarySystemBackgroundColor(void) {
    return PXColorFromClassSelector(@"tertiarySystemBackgroundColor", [UIColor colorWithWhite:0.92 alpha:1.0]);
}

UIColor *PXSystemFillColor(void) {
    return PXColorFromClassSelector(@"systemFillColor", [UIColor colorWithWhite:0.55 alpha:0.20]);
}

UIColor *PXSecondarySystemFillColor(void) {
    return PXColorFromClassSelector(@"secondarySystemFillColor", [UIColor colorWithWhite:0.55 alpha:0.16]);
}

UIColor *PXTertiarySystemFillColor(void) {
    return PXColorFromClassSelector(@"tertiarySystemFillColor", [UIColor colorWithWhite:0.55 alpha:0.12]);
}

UIColor *PXSystemGray2Color(void) {
    return PXColorFromClassSelector(@"systemGray2Color", [UIColor colorWithWhite:0.68 alpha:1.0]);
}

UIColor *PXSystemGray3Color(void) {
    return PXColorFromClassSelector(@"systemGray3Color", [UIColor colorWithWhite:0.78 alpha:1.0]);
}

UIColor *PXSystemGray4Color(void) {
    return PXColorFromClassSelector(@"systemGray4Color", [UIColor colorWithWhite:0.84 alpha:1.0]);
}

UIColor *PXSystemGray5Color(void) {
    return PXColorFromClassSelector(@"systemGray5Color", [UIColor colorWithWhite:0.90 alpha:1.0]);
}

UIColor *PXSystemGray6Color(void) {
    return PXColorFromClassSelector(@"systemGray6Color", [UIColor colorWithWhite:0.95 alpha:1.0]);
}

UIColor *PXSystemIndigoColor(void) {
    return PXColorFromClassSelector(@"systemIndigoColor", [UIColor colorWithRed:0.35 green:0.34 blue:0.84 alpha:1.0]);
}

UIColor *PXSystemGroupedBackgroundColor(void) {
    UIColor *modern = PXColorFromClassSelector(@"systemGroupedBackgroundColor", nil);
    if (modern) return modern;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [UIColor groupTableViewBackgroundColor];
#pragma clang diagnostic pop
}

UIBlurEffect *PXThinMaterialLightBlurEffect(void) {
    if (PXUIKitHasIOS13Features()) {
        return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight];
    }
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight];
}

UIBlurEffect *PXMaterialBlurEffect(void) {
    if (PXUIKitHasIOS13Features()) {
        return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    }
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
}

UIBlurEffect *PXThickMaterialBlurEffect(void) {
    if (PXUIKitHasIOS13Features()) {
        return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterial];
    }
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
}

UIBlurEffect *PXChromeMaterialBlurEffect(void) {
    if (PXUIKitHasIOS13Features()) {
        return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
    }
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
}

UIImage *PXSystemImageNamed(NSString *name) {
    if (name.length == 0) return nil;
    id image = PXCallObject1(UIImage.class, NSSelectorFromString(@"systemImageNamed:"), name);
    return [image isKindOfClass:UIImage.class] ? image : nil;
}

UIImage *PXSystemImageNamedWithPointSize(NSString *name, CGFloat pointSize) {
    UIImage *image = PXSystemImageNamed(name);
    if (!image || pointSize <= 0.0) return image;

    Class configurationClass = NSClassFromString(@"UIImageSymbolConfiguration");
    SEL configurationSelector = NSSelectorFromString(@"configurationWithPointSize:");
    if (!configurationClass || ![configurationClass respondsToSelector:configurationSelector]) return image;

    IMP configurationIMP = [configurationClass methodForSelector:configurationSelector];
    id (*configurationFn)(id, SEL, CGFloat) = (void *)configurationIMP;
    id configuration = configurationFn(configurationClass, configurationSelector, pointSize);
    if (!configuration) return image;

    id configuredImage = PXCallObject1(image, NSSelectorFromString(@"imageWithConfiguration:"), configuration);
    return [configuredImage isKindOfClass:UIImage.class] ? configuredImage : image;
}

UIImage *PXImageWithTintColor(UIImage *image, UIColor *color) {
    if (!image || !color) return image;

    SEL modernSelector = NSSelectorFromString(@"imageWithTintColor:renderingMode:");
    if ([image respondsToSelector:modernSelector]) {
        IMP imp = [image methodForSelector:modernSelector];
        id (*fn)(id, SEL, UIColor *, UIImageRenderingMode) = (void *)imp;
        UIImage *modernImage = fn(image, modernSelector, color, UIImageRenderingModeAlwaysTemplate);
        if ([modernImage isKindOfClass:UIImage.class]) return modernImage;
    }

    CGSize size = image.size;
    if (size.width <= 0.0 || size.height <= 0.0) return image;
    UIGraphicsBeginImageContextWithOptions(size, NO, image.scale);
    CGRect rect = (CGRect){CGPointZero, size};
    [color setFill];
    UIRectFill(rect);
    [image drawInRect:rect blendMode:kCGBlendModeDestinationIn alpha:1.0];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result ?: image;
}

BOOL PXIsDarkUserInterfaceStyle(UITraitCollection *traitCollection) {
    if (!traitCollection) return NO;
    NSInteger style = PXCallInteger0(traitCollection, NSSelectorFromString(@"userInterfaceStyle"), 0);
    return style == 2; // UIUserInterfaceStyleDark
}

UIActivityIndicatorViewStyle PXLargeActivityIndicatorStyle(void) {
    if (PXUIKitHasIOS13Features()) {
        return UIActivityIndicatorViewStyleLarge;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return UIActivityIndicatorViewStyleWhiteLarge;
#pragma clang diagnostic pop
}

UIActivityIndicatorViewStyle PXMediumActivityIndicatorStyle(void) {
    if (PXUIKitHasIOS13Features()) {
        return UIActivityIndicatorViewStyleMedium;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return UIActivityIndicatorViewStyleGray;
#pragma clang diagnostic pop
}

UIFont *PXMonospacedSystemFont(CGFloat size, UIFontWeight weight) {
    SEL selector = NSSelectorFromString(@"monospacedSystemFontOfSize:weight:");
    if ([UIFont respondsToSelector:selector]) {
        IMP imp = [UIFont methodForSelector:selector];
        id (*fn)(id, SEL, CGFloat, UIFontWeight) = (void *)imp;
        UIFont *font = fn(UIFont.class, selector, size, weight);
        if ([font isKindOfClass:UIFont.class]) return font;
    }
    return [UIFont fontWithName:@"Menlo" size:size] ?: [UIFont systemFontOfSize:size weight:weight];
}

void PXSetSegmentedControlSelectedTint(UISegmentedControl *control, UIColor *color) {
    if (!control || !color) return;
    SEL selector = NSSelectorFromString(@"setSelectedSegmentTintColor:");
    if ([control respondsToSelector:selector]) {
        IMP imp = [control methodForSelector:selector];
        void (*fn)(id, SEL, UIColor *) = (void *)imp;
        fn(control, selector, color);
    } else {
        control.tintColor = color;
    }
}

UITableViewStyle PXInsetGroupedTableViewStyle(void) {
    return PXUIKitHasIOS13Features() ? UITableViewStyleInsetGrouped : UITableViewStyleGrouped;
}

UIColor *PXDynamicColor(UIColor *(^provider)(UITraitCollection *traitCollection), UIColor *fallback) {
    if (!provider) return fallback;
    SEL selector = NSSelectorFromString(@"colorWithDynamicProvider:");
    if ([UIColor respondsToSelector:selector]) {
        IMP imp = [UIColor methodForSelector:selector];
        id (*fn)(id, SEL, id) = (void *)imp;
        UIColor *dynamicColor = fn(UIColor.class, selector, provider);
        if ([dynamicColor isKindOfClass:UIColor.class]) return dynamicColor;
    }
    return fallback;
}

id PXForegroundWindowScene(void) {
    UIApplication *application = [UIApplication sharedApplication];
    SEL connectedScenesSelector = NSSelectorFromString(@"connectedScenes");
    id scenesObject = PXCallObject0(application, connectedScenesSelector);
    if (![scenesObject conformsToProtocol:@protocol(NSFastEnumeration)]) return nil;

    Class windowSceneClass = NSClassFromString(@"UIWindowScene");
    if (!windowSceneClass) return nil;

    id fallbackScene = nil;
    for (id scene in scenesObject) {
        if (![scene isKindOfClass:windowSceneClass]) continue;
        if (!fallbackScene) fallbackScene = scene;
        NSInteger activationState = PXCallInteger0(scene, NSSelectorFromString(@"activationState"), -1);
        if (activationState == 0) { // UISceneActivationStateForegroundActive
            return scene;
        }
    }
    return fallbackScene;
}

NSArray<UIWindow *> *PXApplicationWindows(void) {
    UIApplication *application = [UIApplication sharedApplication];
    NSMutableArray<UIWindow *> *windows = [NSMutableArray array];

    SEL connectedScenesSelector = NSSelectorFromString(@"connectedScenes");
    id scenesObject = PXCallObject0(application, connectedScenesSelector);
    Class windowSceneClass = NSClassFromString(@"UIWindowScene");
    if ([scenesObject conformsToProtocol:@protocol(NSFastEnumeration)] && windowSceneClass) {
        NSMutableArray *orderedScenes = [NSMutableArray array];
        id fallbackScene = nil;
        for (id scene in scenesObject) {
            if (![scene isKindOfClass:windowSceneClass]) continue;
            NSInteger activationState = PXCallInteger0(scene, NSSelectorFromString(@"activationState"), -1);
            if (activationState == 0) {
                [orderedScenes addObject:scene];
            } else if (!fallbackScene) {
                fallbackScene = scene;
            }
        }
        if (fallbackScene) [orderedScenes addObject:fallbackScene];

        for (id scene in orderedScenes) {
            id sceneWindows = PXCallObject0(scene, NSSelectorFromString(@"windows"));
            if (![sceneWindows isKindOfClass:NSArray.class]) continue;
            for (id candidate in sceneWindows) {
                if ([candidate isKindOfClass:UIWindow.class] && ![windows containsObject:candidate]) {
                    [windows addObject:candidate];
                }
            }
        }
    }

    if (windows.count == 0) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        for (UIWindow *candidate in application.windows) {
            if ([candidate isKindOfClass:UIWindow.class] && ![windows containsObject:candidate]) {
                [windows addObject:candidate];
            }
        }
#pragma clang diagnostic pop
    }

    id delegate = application.delegate;
    if (windows.count == 0 && [delegate respondsToSelector:@selector(window)]) {
        UIWindow *delegateWindow = [delegate window];
        if ([delegateWindow isKindOfClass:UIWindow.class]) [windows addObject:delegateWindow];
    }

    return [windows copy];
}

UIWindow *PXKeyWindow(void) {
    NSArray<UIWindow *> *windows = PXApplicationWindows();
    for (UIWindow *window in windows) {
        if (window.isKeyWindow) return window;
    }
    for (UIWindow *window in windows) {
        if (!window.hidden && window.alpha > 0.0 && window.rootViewController) return window;
    }
    return windows.firstObject;
}
