//
//  Terminal+AEDesc.m
//  csshx
//
//  Created by Jean-Daniel Dupas on 24/10/2023.
//

#import "Terminal+AEDesc.h"
#import <CoreServices/CoreServices.h>

@interface NSAppleEventDescriptor (ObjectSpecifier)

+ (NSAppleEventDescriptor *)form:(OSType)form want:(OSType)want data:(NSAppleEventDescriptor *)data from:(NSAppleEventDescriptor * __nullable)from;

@end

@implementation TerminalApplication (AEDesc)

- (TerminalTab *)tabWithTTY:(dev_t)tty {
  const char *name = devname(tty, S_IFCHR);
  if (name == nil)
    return nil;

  NSAppleEventDescriptor *obj1 = [NSAppleEventDescriptor form:formPropertyID
                                                         want:cProperty
                                                         data:[NSAppleEventDescriptor descriptorWithTypeCode:'ttty']
                                                         from:[NSAppleEventDescriptor descriptorWithDescriptorType:typeObjectBeingExamined data:nil]];
  NSAppleEventDescriptor *obj2 = [NSAppleEventDescriptor descriptorWithString:[NSString stringWithFormat:@"/dev/%s", name]];

  NSAppleEventDescriptor *testData = [NSAppleEventDescriptor recordDescriptor];
  [testData setDescriptor:[NSAppleEventDescriptor descriptorWithTypeCode:kAEEquals] forKeyword:keyAECompOperator];
  [testData setDescriptor:obj1 forKeyword:keyAEObject1];
  [testData setDescriptor:obj2 forKeyword:keyAEObject2];

  OSType all = kAEAll;
  NSAppleEventDescriptor *windows = [NSAppleEventDescriptor form:formAbsolutePosition
                                                            want:cWindow
                                                            data:[NSAppleEventDescriptor descriptorWithDescriptorType:typeAbsoluteOrdinal bytes:&all length:sizeof(kAEAll)]
                                                            from:nil];

  NSAppleEventDescriptor *directObject = [NSAppleEventDescriptor form:formAbsolutePosition
                                                                 want:'ttab'
                                                                 data:[NSAppleEventDescriptor descriptorWithDescriptorType:typeAbsoluteOrdinal bytes:&all length:sizeof(kAEFirst)]
                                                                 from:windows];

//  NSAppleEventDescriptor *directObject = [NSAppleEventDescriptor form:formTest
//                                                                 want:'ttab'
//                                                                 data:testData
//                                                                 from:windows];

  NSAppleEventDescriptor *aevt = [NSAppleEventDescriptor appleEventWithEventClass:kAECoreSuite
                                                                          eventID:kAEGetData
                                                                 targetDescriptor:[NSAppleEventDescriptor descriptorWithBundleIdentifier:@"com.apple.terminal"]
                                                                         returnID:-17194 transactionID:0];
  [aevt setParamDescriptor:directObject forKeyword:keyDirectObject];

  UInt32 value = 0x00010000;
  OSStatus err = AEPutAttributePtr(aevt.aeDesc,
                                   'csig', /* enumConsidsAndIgnores, */
                                   typeUInt32,
                                   &value,
                                   sizeof(UInt32));

  NSError *error = nil;
  NSAppleEventDescriptor *resp = [aevt sendEventWithOptions:kAEWaitReply timeout:0 error:&error];

//  id tab = [self sendEvent:kAECoreSuite id:kAEGetData
//                parameters:keyDirectObject, directObject, 0];

  return nil;
}

@end

@implementation NSAppleEventDescriptor (ObjectSpecifier)

+ (NSAppleEventDescriptor *)form:(OSType)form want:(OSType)want data:(NSAppleEventDescriptor *)data from:(NSAppleEventDescriptor * __nullable)from {
  NSAppleEventDescriptor *desc = [NSAppleEventDescriptor recordDescriptor];
  [desc setDescriptor:[NSAppleEventDescriptor descriptorWithTypeCode:form] forKeyword:keyAEKeyForm];
  [desc setDescriptor:[NSAppleEventDescriptor descriptorWithTypeCode:want] forKeyword:keyAEDesiredClass];
  [desc setDescriptor:data forKeyword:keyAEKeyData];
  [desc setDescriptor:from ?: [NSAppleEventDescriptor nullDescriptor] forKeyword:keyAEContainer];
  return desc;
}

@end

