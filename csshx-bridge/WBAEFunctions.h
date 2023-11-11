/*
 *  WBAEFunctions.h
 *  WonderBox
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright (c) 2004 - 2023 Jean-Daniel Dupas. All rights reserved.
 *
 *  This file is distributed under the MIT License. See LICENSE.TXT for details.
 */

#if !defined(__WB_AE_FUNCTIONS_H)
#define __WB_AE_FUNCTIONS_H 1

#import <CoreServices/CoreServices.h>

#if !defined(WB_PRIVATE)
#  define WB_PRIVATE extern __attribute__((__visibility__("hidden")))
#endif

#if !defined(WB_INLINE)
#  if !defined(__NO_INLINE__)
#    define WB_INLINE __inline__ __attribute__((__always_inline__)) static
#  else
#    define WB_INLINE __inline__ static
#  endif /* No inline */
#endif

#pragma mark -
#pragma mark AEDesc Constructor & Destructor
/**************************** AEDesc Constructor & Destructor ****************************/

/*!
 @function
 @result Returns a new initialized descriptor
 */
WB_INLINE
AEDesc WBAEEmptyDesc(void) {
  AEDesc desc;
  AEInitializeDescInline(&desc);
  return desc;
}

/*!
 @function
 @abstract Disposes of desc and initialises it to the null descriptor.
           desc must not be nil.
 @param    desc The descriptor you want to dispose. Cannot be nil.
 */
WB_INLINE
OSStatus WBAEDisposeDesc(AEDesc *desc) {
  assert(desc);
  return AEDisposeDesc(desc);
}

#pragma mark -
#pragma mark Create Complex Desc
WB_PRIVATE OSStatus WBAECreateDescFromString(CFStringRef string, AEDesc *desc);

#pragma mark Create Object Specifier
WB_PRIVATE OSStatus WBAECreateObjectSpecifier(DescType desiredType, DescType keyForm, AEDesc *keyData, AEDesc *container, AEDesc *specifier);
WB_PRIVATE OSStatus WBAECreateIndexObjectSpecifier(DescType desiredType, CFIndex idx, AEDesc *container, AEDesc *specifier);
WB_PRIVATE OSStatus WBAECreatePropertyObjectSpecifier(DescType desiredType, AEKeyword property, AEDesc *container, AEDesc *specifier);

#endif /* __WB_AEF_UNCTIONS_H */
