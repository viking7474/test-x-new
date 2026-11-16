#ifndef TLINKIOS_LOGGING_H
#define TLINKIOS_LOGGING_H

#import <Foundation/Foundation.h>

/**
 * Custom logging function for TLinkIOS
 * Emits redacted private os_log diagnostics; file output is opt-in and queued.
 * Diagnostic failures and same-thread recursive logging are contained.
 */
void PXLog(NSString *format, ...);

/**
 * Error logging with recovery attempt
 * @param error The error to log
 * @param context Context description where the error occurred
 */
void PXLogError(NSError *error, NSString *context);

#endif /* TLINKIOS_LOGGING_H */ 