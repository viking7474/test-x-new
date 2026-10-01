#import <Foundation/Foundation.h>

#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
#import <roothide.h>
#endif

NS_ASSUME_NONNULL_BEGIN

/// Resolves a path owned by the jailbreak bootstrap. Rootful/rootless builds keep
/// the supplied path unchanged; RootHide maps it into the randomized jbroot.
static inline NSString *PXJailbreakRootPath(NSString *path) {
    if (![path isKindOfClass:[NSString class]] || path.length == 0) {
        return path;
    }
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    NSString *resolved = jbroot(path);
    return resolved.length ? resolved : path;
#else
    return path;
#endif
}

/// Converts a system-API path into the namespace expected by a bootstrap CLI.
/// On RootHide, bootstrap tools see jbroot as `/` and original iOS paths below
/// `/rootfs`; rootfs() performs that conversion for both kinds of physical path.
static inline NSString *PXBootstrapPathArgument(NSString *path) {
    if (![path isKindOfClass:[NSString class]] || path.length == 0) {
        return path;
    }
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    NSString *resolved = rootfs(path);
    return resolved.length ? resolved : path;
#else
    return path;
#endif
}

/// Converts absolute path arguments while leaving flags, bundle identifiers and
/// other command operands untouched.
static inline NSArray<NSString *> *PXBootstrapArguments(NSArray<NSString *> *arguments) {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    NSMutableArray<NSString *> *converted = [NSMutableArray arrayWithCapacity:arguments.count];
    for (id value in arguments) {
        if ([value isKindOfClass:[NSString class]] && [(NSString *)value hasPrefix:@"/"]) {
            [converted addObject:PXBootstrapPathArgument((NSString *)value)];
        } else if (value) {
            [converted addObject:value];
        }
    }
    return converted;
#else
    return arguments;
#endif
}

/// Prepends RootHide-resolved variants while retaining legacy candidates. The
/// ordered-set behavior avoids duplicate probes in rootful/rootless builds.
static inline NSArray<NSString *> *PXJailbreakPathCandidates(NSArray<NSString *> *paths) {
    NSMutableOrderedSet<NSString *> *candidates = [NSMutableOrderedSet orderedSet];
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    for (id value in paths) {
        if (![value isKindOfClass:[NSString class]] || [(NSString *)value length] == 0) continue;
        NSString *resolved = PXJailbreakRootPath((NSString *)value);
        if (resolved.length) [candidates addObject:resolved];
    }
#endif
    for (id value in paths) {
        if ([value isKindOfClass:[NSString class]] && [(NSString *)value length] > 0) {
            [candidates addObject:(NSString *)value];
        }
    }
    return candidates.array;
}

NS_ASSUME_NONNULL_END
