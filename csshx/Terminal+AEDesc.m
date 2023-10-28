//
//  Terminal+AEDesc.m
//  csshx
//
//  Created by Jean-Daniel Dupas on 24/10/2023.
//

#import "Terminal+AEDesc.h"
#import "WBAEFunctions.h"

@implementation TerminalApplication (AEDesc)

static OSStatus GetTabWhoseTTYEquals(const char *ttyname, AEDesc *test) {
  if (!ttyname || !test)
    return paramErr;

  AEDesc this = WBAEEmptyDesc();
  OSStatus err = AECreateDesc(typeObjectBeingExamined, nil, 0, &this);
  if (noErr != err) return err;

  // property tty from the examined object
  AEDesc obj1 = WBAEEmptyDesc();
  WBAECreatePropertyObjectSpecifier(cProperty, 'ttty', &this, &obj1);
  WBAEDisposeDesc(&this);

  // utxt(/dev/<tty>)
  AEDesc obj2 = WBAEEmptyDesc();
  err = WBAECreateDescFromString((__bridge CFStringRef)[NSString stringWithFormat:@"/dev/%s", ttyname], &obj2);
  if (noErr != err) {
    WBAEDisposeDesc(&obj1);
    return err;
  }

  // operation: obj1 = obj2
  return CreateCompDescriptor(kAEEquals, &obj1, &obj2, true, test);
}

static OSStatus GetWindowsWithNonEmptyName(AEDesc *windows) {
  if (!windows)
    return paramErr;

  AEDesc this = WBAEEmptyDesc();
  OSStatus err = AECreateDesc(typeObjectBeingExamined, nil, 0, &this);
  if (noErr != err) return err;

  // property name from the examined object
  AEDesc obj1 = WBAEEmptyDesc();
  WBAECreatePropertyObjectSpecifier(cProperty, keyAEName, &this, &obj1);
  WBAEDisposeDesc(&this);

  // utxt("")
  AEDesc obj2 = WBAEEmptyDesc();
  err = WBAECreateDescFromString(CFSTR(""), &obj2);
  if (noErr != err) {
    WBAEDisposeDesc(&obj1);
    return err;
  }

  // operation: obj1 = obj2
  AEDesc equals = WBAEEmptyDesc();
  err = CreateCompDescriptor(kAEEquals, &obj1, &obj2, true, &equals);

  AEDesc list = WBAEEmptyDesc();
  err = WBAEDescListCreate(&list, &equals, nil);
  WBAEDisposeDesc(&equals);

  AEDesc not = WBAEEmptyDesc();
  err = CreateLogicalDescriptor(&list, kAENOT, true, &not);

  err = WBAECreateObjectSpecifier(cWindow, formTest, &not, NULL, windows);
  WBAEDisposeDesc(&not);
  return err;
}

- (TerminalTab * __nullable)tabWithTTY:(dev_t)tty {
  const char *name = devname(tty, S_IFCHR);
  if (name == nil)
    return nil;

  // get tabs from windows whose tty = <tty>

  // Create test
  AEDesc test = WBAEEmptyDesc();
  OSStatus err = GetTabWhoseTTYEquals(name, &test);

  // Some Terminal version have a bug where it creates an invisible window that is returned in the window list.
  // That window is a special window that does not supports tab, and so any acces to the windows'tab raise an exception
  // and make the apple event handling failing with a -10000 error.
  // Fortunately, that window is the only one having an empty name, so can be filtered out
  AEDesc windows = WBAEEmptyDesc();
#if 0
  // all windows (from current application)
  err = WBAECreateIndexObjectSpecifier(cWindow, kAEAll, NULL, &windows);
#else
  err = GetWindowsWithNonEmptyName(&windows);
#endif

  // tabs from all windows whose "test"
  AEDesc tab = WBAEEmptyDesc();
  err = WBAECreateObjectSpecifier('ttab', formTest, &test, &windows, &tab);
  WBAEDisposeDesc(&windows);
  WBAEDisposeDesc(&test);

  // using self to send to event to benefit from ScriptingBridge coerce behavior (-> creates TerminalTab instance)
  // returns an array of array with a single tab.
  id result = [self sendEvent:kAECoreSuite id:kAEGetData
                   parameters:keyDirectObject, [[NSAppleEventDescriptor alloc] initWithAEDescNoCopy:&tab], 0];

  while ([result isKindOfClass:NSArray.class] && [result count] == 1) {
    result = result[0];
  }
  // Make sure it has the right type
  if ([result isKindOfClass:TerminalTab.class])
    return result;

  return nil;
}

@end
