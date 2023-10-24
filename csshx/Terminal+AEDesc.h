//
//  Terminal+AEDesc.h
//  csshx
//
//  Created by Jean-Daniel Dupas on 24/10/2023.
//

#import "Terminal.h"

NS_ASSUME_NONNULL_BEGIN

@interface TerminalApplication (AEDesc)
- (TerminalTab *)tabWithTTY:(dev_t)tty;
@end

NS_ASSUME_NONNULL_END
