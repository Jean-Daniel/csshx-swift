//
//  Bridge.h
//  csshx
//
//  Created by Jean-Daniel Dupas on 12/10/2023.
//

#ifndef Bridge_h
#define Bridge_h

#import <Foundation/Foundation.h>

@interface Bridge : NSObject
+ (BOOL)tiocsti:(uint8_t)c error:(NSError **)error;

// Create unix socket

+ (BOOL)setNonBlocking:(dispatch_fd_t)socket error:(NSError **)error;

+ (dispatch_fd_t)bind:(NSString *)path error:(NSError **)error __attribute__((swift_error(zero_result)));

+ (dispatch_fd_t)connect:(NSString *)path error:(NSError **)error __attribute__((swift_error(zero_result)));

@end



#endif /* Bridge_h */
