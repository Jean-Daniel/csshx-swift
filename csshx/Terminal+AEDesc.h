//
//  Terminal+AEDesc.h
//  csshx
//
//  Created by Jean-Daniel Dupas on 24/10/2023.
//

#import "Terminal.h"

NS_ASSUME_NONNULL_BEGIN

// SPI
@interface SBObject  (Private)
- (NSAppleEventDescriptor * __nullable)qualifiedSpecifier;
@end

@interface TerminalApplication (AEDesc)
- (TerminalTab * __nullable)tabWithTTY:(dev_t)tty;
@end

static const AEKeyword kAEProprertyBackground = 'pbcl';

NS_ASSUME_NONNULL_END
