//
//  Bridge.c
//  csshx
//
//  Created by Jean-Daniel Dupas on 12/10/2023.
//

#import <libc.h>
#import "Bridge.h"
#import <spawn.h>

@implementation TTY

+ (BOOL)tiocsti:(uint8_t)c error:(NSError **)error {
  const char value = c;
  if (ioctl(fileno(stdin), TIOCSTI, &value) < 0) {
    *error = [[NSError alloc] initWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
    return false;
  }
  return true;
}

@end
