//
//  Bridge.h
//  csshx
//
//  Created by Jean-Daniel Dupas on 12/10/2023.
//

#ifndef Bridge_h
#define Bridge_h

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface Bridge : NSObject
+ (BOOL)tiocsti:(uint8_t)c error:(NSError ** _Nullable)error;

// Create unix socket

+ (dev_t)getProcessTTY:(pid_t)pid;

+ (BOOL)setNonBlocking:(dispatch_fd_t)fd error:(NSError ** _Nullable)error;

+ (dispatch_fd_t)bind:(NSString *)path umask:(mode_t)perm error:(NSError ** _Nullable)error __attribute__((swift_error(zero_result)));

+ (dispatch_fd_t)connect:(NSString *)path error:(NSError ** _Nullable)error __attribute__((swift_error(zero_result)));

@end

// SPI
@interface NSScreen (UUID)

// May be implemented using
// CGDisplayCreateUUIDFromDisplayID([[[screen deviceDescription] objectForKey:@"NSScreenNumber"] unsignedLongValue])
- (NSString * _Nullable)_UUIDString;
+ (NSScreen  * _Nullable)_screenForUUIDString:(NSString *)uuid;

@end

NS_ASSUME_NONNULL_END

#endif /* Bridge_h */
