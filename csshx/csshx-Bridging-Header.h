//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "Terminal.h"
#import "Bridge.h"
#import "CGSPrivate.h"
#import "Terminal+AEDesc.h"

static const AEKeyword kFromProperty = 'from';
static const AEKeyword kSeldProperty = 'seld';


// SPI
@interface SBObject  (Private)
- (NSAppleEventDescriptor *)qualifiedSpecifier;
@end
