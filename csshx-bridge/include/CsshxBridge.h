//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "Bridge.h"
#import "Terminal.h"
#import "Terminal+AEDesc.h"

NS_ASSUME_NONNULL_BEGIN

// SPI
@interface SBObject (SPI)
- (NSAppleEventDescriptor * __nullable)qualifiedSpecifier;
@end

// SPI
@interface NSScreen (SPI)

// May be implemented using
// CGDisplayCreateUUIDFromDisplayID([[[screen deviceDescription] objectForKey:@"NSScreenNumber"] unsignedLongValue])
// but is less reliable, as it may returns nil during reconfiguration while NSScreen returns a cached value.
- (NSString * _Nullable)_UUIDString;
+ (NSScreen  * _Nullable)_screenForUUIDString:(NSString *)uuid;

@end

NS_ASSUME_NONNULL_END
