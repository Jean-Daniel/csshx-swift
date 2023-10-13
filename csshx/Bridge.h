//
//  Bridge.h
//  csshx
//
//  Created by Jean-Daniel Dupas on 12/10/2023.
//

#ifndef Bridge_h
#define Bridge_h

#import <Foundation/Foundation.h>

@interface TTY : NSObject
+ (BOOL)tiocsti:(uint8_t)c error:(NSError **)error;
@end

#endif /* Bridge_h */
