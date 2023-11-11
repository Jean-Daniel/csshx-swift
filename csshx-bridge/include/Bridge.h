//
//  Bridge.h
//  csshx
//
//  Created by Jean-Daniel Dupas.
//

#ifndef Bridge_h
#define Bridge_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Termios : NSObject

+ (dev_t)getProcessTTY:(pid_t)pid;

+ (BOOL)tiocsti:(uint8_t)c error:(NSError ** _Nullable)error;

@end

@interface Socket : NSObject

+ (dispatch_fd_t)bind:(NSString *)path umask:(mode_t)perm error:(NSError ** _Nullable)error __attribute__((swift_error(zero_result)));

+ (dispatch_fd_t)connect:(NSString *)path error:(NSError ** _Nullable)error __attribute__((swift_error(zero_result)));

@end

NS_ASSUME_NONNULL_END

#endif /* Bridge_h */
