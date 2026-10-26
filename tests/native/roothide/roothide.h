#pragma once

#if !defined(PX_SOURCE_TRANSACTION_TESTING) || !defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
#error "This RootHide path shim is only for the native source-transaction fixture"
#endif

#import <Foundation/Foundation.h>

// The macOS lifecycle fixture supplies temporary profile paths. It does not
// test RootHide namespace translation or replace the production RootHide SDK.
// CarrierDB pulls in PXJailbreakCompat.h, which needs both NSString adapters.
static inline NSString *jbroot(NSString *path) { return path; }
static inline NSString *rootfs(NSString *path) { return path; }
