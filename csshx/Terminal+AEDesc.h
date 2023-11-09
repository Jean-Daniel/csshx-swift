//
//  Terminal+AEDesc.h
//  csshx
//
//  Created by Jean-Daniel Dupas.
//

#import "Terminal.h"

NS_ASSUME_NONNULL_BEGIN

// SPI
@interface SBObject (SPI)
- (NSAppleEventDescriptor * __nullable)qualifiedSpecifier;
@end

@interface TerminalApplication (AEDesc)
- (TerminalTab * __nullable)tabWithTTY:(dev_t)tty;
@end

NS_ASSUME_NONNULL_END
