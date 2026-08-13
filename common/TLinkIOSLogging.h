#ifndef TLINKIOS_LOGGING_H
#define TLINKIOS_LOGGING_H

#import <Foundation/Foundation.h>

/**
 * Custom logging function for TLinkIOS
 * Writes logs to both NSLog and a file
 */
void PXLog(NSString *format, ...);

/**
 * Error logging with recovery attempt
 * @param error The error to log
 * @param context Context description where the error occurred
 */
void PXLogError(NSError *error, NSString *context);

#endif /* TLINKIOS_LOGGING_H */ 