//
//  Terminal+AEDesc.h
//  csshx
//
//  Created by Jean-Daniel Dupas.
//

#import "Terminal.h"

NS_ASSUME_NONNULL_BEGIN

@interface TerminalApplication (AEDesc)
- (TerminalTab * __nullable)tabWithTTY:(dev_t)tty;
@end

NS_ASSUME_NONNULL_END
