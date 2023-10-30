//
//  CGSPrivate.h
//  Header file for undocumented CoreGraphics SPI
//
//  Arranged by Nicholas Jitkoff
//  Based on CGSPrivate.h by Richard Wareham
//
//  Contributors:
//    Austin Sarner: Shadows
//    Jason Harris: Filters, Shadows, Regions
//    Kevin Ballard: Warping
//    Steve Voida: Workspace notifications
//    Tony Arnold: Workspaces notifications enum filters
//    Ben Gertzfield: CGSRemoveConnectionNotifyProc
//
//  Changes:
//    2.3 - Added the CGSRemoveConnectionNotifyProc method with the help of Ben Gertzfield
//    2.2 - Moved back to CGSPrivate, added more enums to the CGSConnectionNotifyEvent
//    2.1 - Added spaces notifications
//    2.0 - Original Release

#include <CoreGraphics/CoreGraphics.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void* CGSConnectionID;
typedef int CGSWorkspace;
typedef int CGSValue;

#pragma mark Listing Windows
/* Get the default connection for the current process. */
extern CGSConnectionID _CGSDefaultConnection(void);
static inline CGSConnectionID CGSDefaultConnection() { return _CGSDefaultConnection(); }
// Disable/Enable Screen Updates
extern CGError CGSDisableUpdate(CGSConnectionID cid);
extern CGError CGSReenableUpdate(CGSConnectionID cid);

#pragma mark Listing Windows

// Get window counts and lists.
extern CGError CGSGetWindowCount(const CGSConnectionID cid, CGSConnectionID targetCID, int* outCount);
extern CGError CGSGetWindowList(const CGSConnectionID cid, CGSConnectionID targetCID, int count, int* list, int* outCount);

// Get on-screen window counts and lists.
extern CGError CGSGetOnScreenWindowCount(const CGSConnectionID cid, CGSConnectionID targetCID, int* outCount);
extern CGError CGSGetOnScreenWindowList(const CGSConnectionID cid, CGSConnectionID targetCID, int count, int* list, int* outCount);

// Per-workspace window counts and lists.
extern CGError CGSGetWorkspaceWindowCount(const CGSConnectionID cid, CGSWorkspace workspaceNumber, int *outCount);
extern CGError CGSGetWorkspaceWindowList(const CGSConnectionID cid, CGSWorkspace workspaceNumber, int count, int* list, int* outCount);

#pragma mark Window Manipulation

// Window Level
extern CGError CGSGetWindowLevel(const CGSConnectionID cid, CGWindowID wid, CGWindowLevel *level);
extern CGError CGSSetWindowLevel(const CGSConnectionID cid, CGWindowID wid, CGWindowLevel level);

// Window ordering
typedef enum _CGSWindowOrderingMode {
  kCGSOrderAbove                =  1, // Window is ordered above target.
  kCGSOrderBelow                = -1, // Window is ordered below target.
  kCGSOrderOut                  =  0  // Window is removed from the on-screen window list.
} CGSWindowOrderingMode;

extern CGError CGSOrderWindow(const CGSConnectionID cid, const CGWindowID wid, CGSWindowOrderingMode place, CGWindowID relativeToWindowID /* can be NULL */);
extern CGError CGSWindowIsOrderedIn(const CGSConnectionID cid, const CGWindowID wid, Boolean *result);

extern CGError CGSUncoverWindow(const CGSConnectionID cid, const CGWindowID wid);
extern CGError CGSFlushWindow(const CGSConnectionID cid, const CGWindowID wid, int unknown /* 0 works */ );

// Position
extern CGError CGSGetWindowBounds(CGSConnectionID cid, CGWindowID wid, CGRect *outBounds);
extern CGError CGSGetScreenRectForWindow(const CGSConnectionID cid, CGWindowID wid, CGRect *outRect);
extern CGError CGSMoveWindow(const CGSConnectionID cid, const CGWindowID wid, CGPoint *point);
extern CGError CGSSetWindowTransform(const CGSConnectionID cid, const CGWindowID wid, CGAffineTransform transform);
extern CGError CGSGetWindowTransform(const CGSConnectionID cid, const CGWindowID wid, CGAffineTransform * outTransform);
extern CGError CGSSetWindowTransforms(const CGSConnectionID cid, CGWindowID *wids, CGAffineTransform *transform, int n);

// Alpha
extern CGError CGSSetWindowAlpha(const CGSConnectionID cid, const CGWindowID wid, float alpha);
extern CGError CGSSetWindowListAlpha(const CGSConnectionID cid, CGWindowID *wids, int count, float alpha);
extern CGError CGSGetWindowAlpha(const CGSConnectionID cid, const CGWindowID wid, float* alpha);

// Brightness
extern CGError CGSSetWindowListBrightness(const CGSConnectionID cid, CGWindowID *wids, float *brightness, int count);

// Workspace
extern CGError CGSMoveWorkspaceWindows(const CGSConnectionID connection, CGSWorkspace toWorkspace, CGSWorkspace fromWorkspace);
extern CGError CGSMoveWorkspaceWindowList(const CGSConnectionID connection, CGWindowID *wids, int count, CGSWorkspace toWorkspace);

// Shadow
extern CGError CGSSetWindowShadowAndRimParameters(const CGSConnectionID cid, CGWindowID wid, float standardDeviation, float density, int offsetX, int offsetY, unsigned int flags);
extern CGError CGSGetWindowShadowAndRimParameters(const CGSConnectionID cid, CGWindowID wid, float* standardDeviation, float* density, int *offsetX, int *offsetY, unsigned int *flags);

// Properties
extern CGError CGSGetWindowProperty(const CGSConnectionID cid, CGWindowID wid, CGSValue key, CGSValue *outValue);
extern CGError CGSSetWindowProperty(const CGSConnectionID cid, CGWindowID wid, CGSValue key, CGSValue *outValue);

// Owner
extern CGError CGSGetWindowOwner(const CGSConnectionID cid, const CGWindowID wid, CGSConnectionID *ownerCid);
extern CGError CGSConnectionGetPID(const CGSConnectionID cid, pid_t *pid, const CGSConnectionID ownerCid);

#pragma mark Window Tags

typedef enum {
  CGSTagNone          = 0,        // No tags
  CGSTagExposeFade    = 0x0002,    // Fade out when Expose activates.
  CGSTagNoShadow      = 0x0008,    // No window shadow.
  CGSTagTransparent   = 0x0200,   // Transparent to mouse clicks.
  CGSTagSticky        = 0x0800,    // Appears on all workspaces.
} CGSWindowTag;

// thirtyTwo must = 32 for some reason.
// tags is a pointer to an array of ints (size 2?). First entry holds window tags.
extern CGError CGSGetWindowTags(const CGSConnectionID cid, const CGWindowID wid, CGSWindowTag *tags, int thirtyTwo);
extern CGError CGSSetWindowTags(const CGSConnectionID cid, const CGWindowID wid, CGSWindowTag *tags, int thirtyTwo);
extern CGError CGSClearWindowTags(const CGSConnectionID cid, const CGWindowID wid, CGSWindowTag *tags, int thirtyTwo);
extern CGError CGSGetWindowEventMask(const CGSConnectionID cid, const CGWindowID wid, uint32_t *mask);
extern CGError CGSSetWindowEventMask(const CGSConnectionID cid, const CGWindowID wid, uint32_t mask);

# pragma mark Window Warping

typedef struct {
  CGPoint local;
  CGPoint global;
} CGPointWarp;

extern CGError CGSSetWindowWarp(const CGSConnectionID cid, const CGWindowID wid, int w, int h, CGPointWarp mesh[h][w]);

# pragma mark Window Core Image Filters

typedef void *CGSWindowFilterRef;
extern CGError CGSNewCIFilterByName(CGSConnectionID cid, CFStringRef filterName, CGSWindowFilterRef *outFilter);
extern CGError CGSAddWindowFilter(CGSConnectionID cid, CGWindowID wid, CGSWindowFilterRef filter, int flags);
extern CGError CGSRemoveWindowFilter(CGSConnectionID cid, CGWindowID wid, CGSWindowFilterRef filter);
extern CGError CGSReleaseCIFilter(CGSConnectionID cid, CGSWindowFilterRef filter);
extern CGError CGSSetCIFilterValuesFromDictionary(CGSConnectionID cid, CGSWindowFilterRef filter, CFDictionaryRef filterValues);

#pragma mark Transitions

typedef enum {
  CGSNone = 0,          // No transition effect.
  CGSFade,              // Cross-fade.
  CGSZoom,              // Zoom/fade towards us.
  CGSReveal,            // Reveal new desktop under old.
  CGSSlide,              // Slide old out and new in.
  CGSWarpFade,          // Warp old and fade out revealing new.
  CGSSwap,              // Swap desktops over graphically.
  CGSCube,              // The well-known cube effect.
  CGSWarpSwitch,        // Warp old, switch and un-warp.
  CGSFlip,              // Flip over
  CGSTransparentBackgroundMask = (1<<7) // OR this with any other type to get a transparent background
} CGSTransitionType;

typedef enum {
  CGSDown,              // Old desktop moves down.
  CGSLeft,              // Old desktop moves left.
  CGSRight,              // Old desktop moves right.
  CGSInRight,            // CGSSwap: Old desktop moves into screen, new comes from right.
  CGSBottomLeft = 5,    // CGSSwap: Old desktop moves to bl, new comes from tr.
  CGSBottomRight,        // CGSSwap: Old desktop to br, New from tl.
  CGSDownTopRight,      // CGSSwap: Old desktop moves down, new from tr.
  CGSUp,                // Old desktop moves up.
  CGSTopLeft,            // Old desktop moves tl.
  CGSTopRight,          // CGSSwap: old to tr. new from bl.
  CGSUpBottomRight,      // CGSSwap: old desktop up, new from br.
  CGSInBottom,          // CGSSwap: old in, new from bottom.
  CGSLeftBottomRight,    // CGSSwap: old one moves left, new from br.
  CGSRightBottomLeft,    // CGSSwap: old one moves right, new from bl.
  CGSInBottomRight,      // CGSSwap: onl one in, new from br.
  CGSInOut              // CGSSwap: old in, new out.
} CGSTransitionOption;

typedef struct {
  uint32_t unknown1;
  CGSTransitionType type;
  CGSTransitionOption option;
  CGWindowID wid;      /* Can be 0 for full-screen */
  float *backColour;  /* Null for black otherwise pointer to 3 float array with RGB value */
} CGSTransitionSpec;

extern CGError CGSNewTransition(const CGSConnectionID cid, const CGSTransitionSpec* spec, int *pTransitionHandle);
extern CGError CGSInvokeTransition(const CGSConnectionID cid, int transitionHandle, float duration);
extern CGError CGSReleaseTransition(const CGSConnectionID cid, int transitionHandle);

#pragma mark Workspaces

extern CGError CGSGetWorkspace(const CGSConnectionID cid, CGSWorkspace *workspace);
extern CGError CGSGetWindowWorkspace(const CGSConnectionID cid, const CGWindowID wid, CGSWorkspace *workspace);
extern CGError CGSSetWorkspace(const CGSConnectionID cid, CGSWorkspace workspace);
extern CGError CGSSetWorkspaceWithTransition(const CGSConnectionID cid, CGSWorkspace workspace, CGSTransitionType transition, CGSTransitionOption subtype, float time);

typedef enum {
  CGSScreenResolutionChangedEvent = 100,
  CGSConnectionNotifyEventUnknown2 = 101,
  CGSConnectionNotifyEventUnknown3 = 102,
  CGSConnectionNotifyEventUnknown4 = 103,
  CGSClientEnterFullscreen = 106,
  CGSClientExitFullscreen = 107,
  CGSConnectionNotifyEventUnknown7 = 750,
  CGSConnectionNotifyEventUnknown8 = 751,
  CGSWorkspaceConfigurationDisabledEvent = 761, // Seems to occur when objects are removed (rows/columns), or disabled
  CGSWorkspaceConfigurationEnabledEvent = 762,  // Seems to occur when objects are added (rows/columns), or enabled
  CGSConnectionNotifyEventUnknown9 = 763,
  CGSConnectionNotifyEventUnknown10 = 764,
  CGSConnectionNotifyEventUnknown11 = 806,
  CGSConnectionNotifyEventUnknown12 = 807,
  CGSConnectionNotifyEventUnknown13 = 1201,  // Seems to occur when applications are launched/quit. Is this a connection being created/destroyed by the application to the window server?
  CGSWorkspaceChangedEvent = 1401,
  CGSConnectionNotifyEventUnknown14 = 1409,
  CGSConnectionNotifyEventUnknown15 = 1410,
  CGSConnectionNotifyEventUnknown16 = 1411,
  CGSConnectionNotifyEventUnknown17 = 1412,
  CGSConnectionNotifyEventUnknown18 = 1500,
  CGSConnectionNotifyEventUnknown19 = 1501,
  CGSConnectionNotifyEventUnknown20 = 1700
} CGSConnectionNotifyEvent;

/* Prototype for the Spaces change notification callback.
 *
 * data1 -- returns whatever value is passed to data1 parameter in CGSRegisterConnectionNotifyProc
 * data2 -- indeterminate (always a large negative integer; seems to be limited to a small set of values)
 * data3 -- indeterminate (always returns the number '4' for me)
 * userParameter -- returns whatever value is passed to userParameter in CGSRegisterConnectionNotifyProc
 */

typedef void (*CGConnectionNotifyProc)(int data1, int data2, int data3, void* userParameter);

/* Register a callback function to receive notifications about when
 the current Space is changing.
 *
 * cid -- Current connection
 * function -- A pointer to the intended callback function (must be in C; cannot be an Objective-C selector)
 * event -- indeterminate (this is hard-coded to 0x579 in Spaces.menu...perhpas some kind of event filter code?) -- use CGSWorkspaceChangedEvent in this for now
 * userParameter -- pointer to user-defined auxiliary information structure; passed directly to callback proc
 */

// For spaces notifications: CGSRegisterConnectionNotifyProc(_CGSDefaultConnection(), spacesCallback, 1401, (void*)userInfo);

extern CGError CGSRegisterConnectionNotifyProc(const CGSConnectionID cid, CGConnectionNotifyProc function, CGSConnectionNotifyEvent event, void* userParameter);

extern CGError CGSRemoveConnectionNotifyProc(const CGSConnectionID cid, CGConnectionNotifyProc function, CGSConnectionNotifyEvent event, void* userParameter);

# pragma mark Miscellaneous

// Regions
typedef void *CGSRegionRef;
extern CGError CGSNewRegionWithRect(CGRect const *inRect, CGSRegionRef *outRegion);
extern CGError CGSNewEmptyRegion(CGSRegionRef *outRegion);
extern CGError CGSReleaseRegion(CGSRegionRef region);

// Creating Windows
extern CGError CGSNewWindowWithOpaqueShape(CGSConnectionID cid, int always2, float x, float y, CGSRegionRef shape, CGSRegionRef opaqueShape, int unknown1, void *unknownPtr, int always32, CGWindowID *outWID);
extern CGError CGSReleaseWindow(CGSConnectionID cid, CGWindowID wid);
extern CGContextRef CGWindowContextCreate(CGSConnectionID cid, CGWindowID wid, void *unknown);

// Values
extern int CGSIntegerValue(CGSValue intVal);
extern void *CGSReleaseGenericObj(void*);

// Deprecated in 10.5
extern CGSValue CGSCreateCStringNoCopy(const char *str); //Normal CFStrings will work
extern CGSValue CGSCreateCString(const char* str);
extern char* CGSCStringValue(CGSValue string);

#pragma mark Debugging

// These all create files called /tmp/WindowServer + suffix
#define kCGSDumpWindowInfo 0x80000001 // .winfo.out
#define kCGSDumpConnectionInfo 0x80000002 // .cinfo.out
#define kCGSDumpKeyInfo 0x8000000e // .keyinfo.out
#define kCGSDumpSurfaceInfo 0x80000010 // .sinfo.out
#define kCGSDumpGLInfo 0x80000013 // .glinfo.out
#define kCGSDumpShadowInfo 0x80000014 //.shinfo.out
#define kCGSDumpStoragesAndCachesInfo 0x80000015 // .scinfo.out
#define kCGSDumpWindowPlistInfo 0x80000017 // .winfo.plist
                                           // Other flags:
#define kCGSDebugOptionNormal 0 // Reset everything
#define kCGSFlashScreenUpdates 4 // This is probably what the checkbox in Quartz Debug calls internally
typedef unsigned long CGSDebugOptions;

extern void CGSSetDebugOptions(CGSDebugOptions options);

// Missing functions

//CGSIntersectRegionWithRect
//CGSSetWindowTransformsAtPlacement
//CGSSetWindowListGlobalClipShape
//extern CGError CGSWindowAddRectToDirtyShape(const CGSConnectionID cid, const CGSWindow wid, CGRect *rect);

#ifdef __cplusplus
}
#endif
