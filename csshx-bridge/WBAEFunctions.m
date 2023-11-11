/*
 *  WBAEFunctions.c
 *  WonderBox
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright (c) 2004 - 2023 Jean-Daniel Dupas. All rights reserved.
 *
 *  This file is distributed under the MIT License. See LICENSE.TXT for details.
 */

#import <Foundation/Foundation.h>

#import "WBAEFunctions.h"

#pragma mark -
#pragma mark Create Object Specifier
OSStatus WBAECreateDescFromString(CFStringRef string, AEDesc *desc) {
  if (!string || !desc) return paramErr;

  CFIndex length = CFStringGetLength(string);
  // Note: We need to check Size (aka long) overflow.
  // It should be (lenght * sizeof(UniChar) > LONG_MAX), but it may overflow
  if (length > (LONG_MAX / (Size)sizeof(UniChar)))
    return paramErr;

  /* Create Unicode String */
  /* Use stack if length < 512, else use heap */
  UniChar stackStr[512];
  UniChar *buffer = NULL;

  const UniChar *chars = CFStringGetCharactersPtr(string);
  if (!chars) {
    if (length <= 512) {
      chars = stackStr;
    } else {
      buffer = malloc(sizeof(UniChar) * length);
      chars = buffer;
    }
    CFStringGetCharacters(string, CFRangeMake(0, length), (UniChar *)chars);
  }

  OSStatus err = AECreateDesc(typeUnicodeText, chars, length * sizeof(*chars), desc);
  if (buffer)
    free(buffer);
  return err;
}

OSStatus WBAECreateObjectSpecifier(DescType desiredType, DescType keyForm, AEDesc *keyData, AEDesc *container, AEDesc *specifier) {
  if (!keyData || !specifier) return paramErr;

  OSStatus err;
  AEDesc appli = WBAEEmptyDesc();
  err = CreateObjSpecifier(desiredType, (container) ? container : &appli, keyForm, keyData, false, specifier);

  return err;
}

OSStatus WBAECreateIndexObjectSpecifier(DescType desiredType, CFIndex idx, AEDesc *container, AEDesc *specifier) {
  if (!specifier)
    return paramErr;

  OSStatus err;
  AEDesc keyData = WBAEEmptyDesc();

  switch (idx) {
      /* Absolute index case */
    case kAEAny:
    case kAEAll:
    case kAELast:
    case kAEFirst:
    case kAEMiddle: {
      OSType absIdx = (OSType)idx;
      err = AECreateDesc(typeAbsoluteOrdinal, &absIdx, sizeof(OSType), &keyData);
    }
      break;
      /* General case */
    default:
#if defined(__LP64__) && __LP64__
      err = AECreateDesc(typeSInt64, &idx, sizeof(SInt64), &keyData);
#else
      err = AECreateDesc(typeSInt32, &idx, sizeof(SInt32), &keyData);
#endif
  }

  if (noErr == err)
    err = WBAECreateObjectSpecifier(desiredType, formAbsolutePosition, &keyData, container, specifier);

  WBAEDisposeDesc(&keyData);
  return err;
}

OSStatus WBAECreatePropertyObjectSpecifier(DescType desiredType, AEKeyword property, AEDesc *container, AEDesc *specifier) {
  if (!specifier)
    return paramErr;

  AEDesc keyData = WBAEEmptyDesc();
  OSStatus err = AECreateDesc(typeType, &property, sizeof(AEKeyword), &keyData);
  if (noErr == err)
    err = WBAECreateObjectSpecifier(desiredType, formPropertyID, &keyData, container, specifier);

  WBAEDisposeDesc(&keyData);
  return err;
}

