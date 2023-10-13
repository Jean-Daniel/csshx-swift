/*
 * Terminal.m
 */

#include "Terminal.h"


/*
 * Standard Suite
 */

@implementation TerminalApplication

typedef struct { NSString *name; FourCharCode code; } classForCode_t;
static const classForCode_t classForCodeData__[] = {
	{ @"TerminalApplication", 'capp' },
	{ @"TerminalWindow", 'cwin' },
	{ @"TerminalSettingsSet", 'tprf' },
	{ @"TerminalTab", 'ttab' },
	{ nil, 0 } 
};

- (NSDictionary *) classNamesForCodes
{
	static NSMutableDictionary *dict__;

	if (!dict__) @synchronized([self class]) {
	if (!dict__) {
		dict__ = [[NSMutableDictionary alloc] init];
		const classForCode_t *p;
		for (p = classForCodeData__; p->name != nil; ++p)
			[dict__ setObject:p->name forKey:[NSNumber numberWithUnsignedInt:p->code]];
	} }
	return dict__;
}

typedef struct { FourCharCode code; NSString *name; } codeForPropertyName_t;
static const codeForPropertyName_t codeForPropertyNameData__[] = {
	{ 'lwcp', @"copies" },
	{ 'lwcl', @"collating" },
	{ 'lwfp', @"startingPage" },
	{ 'lwlp', @"endingPage" },
	{ 'lwla', @"pagesAcross" },
	{ 'lwld', @"pagesDown" },
	{ 'lweh', @"errorHandling" },
	{ 'faxn', @"faxNumber" },
	{ 'trpr', @"targetPrinter" },
	{ 'pnam', @"name" },
	{ 'pisf', @"frontmost" },
	{ 'vers', @"version" },
	{ 'pnam', @"name" },
	{ 'ID  ', @"id" },
	{ 'pidx', @"index" },
	{ 'pbnd', @"bounds" },
	{ 'hclb', @"closeable" },
	{ 'ismn', @"miniaturizable" },
	{ 'pmnd', @"miniaturized" },
	{ 'prsz', @"resizable" },
	{ 'pvis', @"visible" },
	{ 'iszm', @"zoomable" },
	{ 'pzum', @"zoomed" },
	{ 'pisf', @"frontmost" },
	{ 'ppos', @"position" },
	{ 'pori', @"origin" },
	{ 'psiz', @"size" },
	{ 'pfra', @"frame" },
	{ 'tdpr', @"defaultSettings" },
	{ 'tspr', @"startupSettings" },
	{ 'ID  ', @"id" },
	{ 'pnam', @"name" },
	{ 'crow', @"numberOfRows" },
	{ 'ccol', @"numberOfColumns" },
	{ 'pcuc', @"cursorColor" },
	{ 'pbcl', @"backgroundColor" },
	{ 'ptxc', @"normalTextColor" },
	{ 'pbtc', @"boldTextColor" },
	{ 'font', @"fontName" },
	{ 'ptsz', @"fontSize" },
	{ 'panx', @"fontAntialiasing" },
	{ 'tcln', @"cleanCommands" },
	{ 'tddn', @"titleDisplaysDeviceName" },
	{ 'tdsp', @"titleDisplaysShellPath" },
	{ 'tdws', @"titleDisplaysWindowSize" },
	{ 'tdsn', @"titleDisplaysSettingsName" },
	{ 'tdct', @"titleDisplaysCustomTitle" },
	{ 'titl', @"customTitle" },
	{ 'crow', @"numberOfRows" },
	{ 'ccol', @"numberOfColumns" },
	{ 'pcnt', @"contents" },
	{ 'hist', @"history" },
	{ 'busy', @"busy" },
	{ 'prcs', @"processes" },
	{ 'tbsl', @"selected" },
	{ 'tdct', @"titleDisplaysCustomTitle" },
	{ 'titl', @"customTitle" },
	{ 'ttty', @"tty" },
	{ 'tcst', @"currentSettings" },
	{ 'pcuc', @"cursorColor" },
	{ 'pbcl', @"backgroundColor" },
	{ 'ptxc', @"normalTextColor" },
	{ 'pbtc', @"boldTextColor" },
	{ 'tcln', @"cleanCommands" },
	{ 'tddn', @"titleDisplaysDeviceName" },
	{ 'tdsp', @"titleDisplaysShellPath" },
	{ 'tdws', @"titleDisplaysWindowSize" },
	{ 'tdfn', @"titleDisplaysFileName" },
	{ 'font', @"fontName" },
	{ 'ptsz', @"fontSize" },
	{ 'panx', @"fontAntialiasing" },
	{ 0, nil } 
};

- (NSDictionary *) codesForPropertyNames
{
	static NSMutableDictionary *dict__;

	if (!dict__) @synchronized([self class]) {
	if (!dict__) {
		dict__ = [[NSMutableDictionary alloc] init];
		const codeForPropertyName_t *p;
		for (p = codeForPropertyNameData__; p->name != nil; ++p)
			[dict__ setObject:[NSNumber numberWithUnsignedInt:p->code] forKey:p->name];
	} }
	return dict__;
}


- (SBElementArray *) windows
{
	return [self elementArrayWithCode:'cwin'];
}


- (NSString *) name
{
	return [[self propertyWithCode:'pnam'] get];
}

- (BOOL) frontmost
{
	id v = [[self propertyWithCode:'pisf'] get];
	return [v boolValue];
}

- (NSString *) version
{
	return [[self propertyWithCode:'vers'] get];
}


- (void) open:(NSArray<NSURL *> *)x
{
	[self sendEvent:'aevt' id:'odoc' parameters:'----', x, 0];
}

- (void) print:(id)x withProperties:(NSDictionary *)withProperties printDialog:(BOOL)printDialog
{
	[self sendEvent:'aevt' id:'pdoc' parameters:'----', x, 'prdt', withProperties, 'pdlg', [NSNumber numberWithBool:printDialog], 0];
}

- (void) quitSaving:(TerminalSaveOptions)saving
{
	[self sendEvent:'aevt' id:'quit' parameters:'savo', [NSAppleEventDescriptor descriptorWithEnumCode:saving], 0];
}

- (TerminalTab *) doScript:(NSString *)x in:(id)in_
{
	id result__ = [self sendEvent:'core' id:'dosc' parameters:'----', x, 'kfil', in_, 0];
	return result__;
}

@end


@implementation TerminalWindow

- (SBElementArray *) tabs
{
	return [self elementArrayWithCode:'ttab'];
}


- (NSString *) name
{
	return [[self propertyWithCode:'pnam'] get];
}

- (NSInteger) id
{
	id v = [[self propertyWithCode:'ID  '] get];
	return [v integerValue];
}

- (NSInteger) index
{
	id v = [[self propertyWithCode:'pidx'] get];
	return [v integerValue];
}

- (void) setIndex: (NSInteger) index
{
	id v = [NSNumber numberWithInteger:index];
	[[self propertyWithCode:'pidx'] setTo:v];
}

- (NSRect) bounds
{
	id v = [[self propertyWithCode:'pbnd'] get];
	return [v rectValue];
}

- (void) setBounds: (NSRect) bounds
{
	id v = [NSValue valueWithRect:bounds];
	[[self propertyWithCode:'pbnd'] setTo:v];
}

- (BOOL) closeable
{
	id v = [[self propertyWithCode:'hclb'] get];
	return [v boolValue];
}

- (BOOL) miniaturizable
{
	id v = [[self propertyWithCode:'ismn'] get];
	return [v boolValue];
}

- (BOOL) miniaturized
{
	id v = [[self propertyWithCode:'pmnd'] get];
	return [v boolValue];
}

- (void) setMiniaturized: (BOOL) miniaturized
{
	id v = [NSNumber numberWithBool:miniaturized];
	[[self propertyWithCode:'pmnd'] setTo:v];
}

- (BOOL) resizable
{
	id v = [[self propertyWithCode:'prsz'] get];
	return [v boolValue];
}

- (BOOL) visible
{
	id v = [[self propertyWithCode:'pvis'] get];
	return [v boolValue];
}

- (void) setVisible: (BOOL) visible
{
	id v = [NSNumber numberWithBool:visible];
	[[self propertyWithCode:'pvis'] setTo:v];
}

- (BOOL) zoomable
{
	id v = [[self propertyWithCode:'iszm'] get];
	return [v boolValue];
}

- (BOOL) zoomed
{
	id v = [[self propertyWithCode:'pzum'] get];
	return [v boolValue];
}

- (void) setZoomed: (BOOL) zoomed
{
	id v = [NSNumber numberWithBool:zoomed];
	[[self propertyWithCode:'pzum'] setTo:v];
}

- (BOOL) frontmost
{
	id v = [[self propertyWithCode:'pisf'] get];
	return [v boolValue];
}

- (void) setFrontmost: (BOOL) frontmost
{
	id v = [NSNumber numberWithBool:frontmost];
	[[self propertyWithCode:'pisf'] setTo:v];
}

- (TerminalTab *) selectedTab
{
	return (TerminalTab *) [self propertyWithClass:[TerminalTab class] code:'tcnt'];
}

- (void) setSelectedTab: (TerminalTab *) selectedTab
{
	[[self propertyWithClass:[TerminalTab class] code:'tcnt'] setTo:selectedTab];
}

- (NSPoint) position
{
	id v = [[self propertyWithCode:'ppos'] get];
	return [v pointValue];
}

- (void) setPosition: (NSPoint) position
{
	id v = [NSValue valueWithPoint:position];
	[[self propertyWithCode:'ppos'] setTo:v];
}

- (NSPoint) origin
{
	id v = [[self propertyWithCode:'pori'] get];
	return [v pointValue];
}

- (void) setOrigin: (NSPoint) origin
{
	id v = [NSValue valueWithPoint:origin];
	[[self propertyWithCode:'pori'] setTo:v];
}

- (NSPoint) size
{
	id v = [[self propertyWithCode:'psiz'] get];
	return [v pointValue];
}

- (void) setSize: (NSPoint) size
{
	id v = [NSValue valueWithPoint:size];
	[[self propertyWithCode:'psiz'] setTo:v];
}

- (NSRect) frame
{
	id v = [[self propertyWithCode:'pfra'] get];
	return [v rectValue];
}

- (void) setFrame: (NSRect) frame
{
	id v = [NSValue valueWithRect:frame];
	[[self propertyWithCode:'pfra'] setTo:v];
}



- (void) closeSaving:(TerminalSaveOptions)saving savingIn:(NSURL *)savingIn
{
	[self sendEvent:'core' id:'clos' parameters:'savo', [NSAppleEventDescriptor descriptorWithEnumCode:saving], 'kfil', savingIn, 0];
}

- (void) saveIn:(NSURL *)in_
{
	[self sendEvent:'core' id:'save' parameters:'kfil', in_, 0];
}

- (void) printWithProperties:(NSDictionary *)withProperties printDialog:(BOOL)printDialog
{
	[self sendEvent:'aevt' id:'pdoc' parameters:'prdt', withProperties, 'pdlg', [NSNumber numberWithBool:printDialog], 0];
}

- (void) delete
{
	[self sendEvent:'core' id:'delo' parameters:0];
}

- (void) duplicateTo:(SBObject *)to withProperties:(NSDictionary *)withProperties
{
	[self sendEvent:'core' id:'clon' parameters:'insh', to, 'prdt', withProperties, 0];
}

- (BOOL) exists
{
	id result__ = [self sendEvent:'core' id:'doex' parameters:0];
	return [result__ boolValue];
}

- (void) moveTo:(SBObject *)to
{
	[self sendEvent:'core' id:'move' parameters:'insh', to, 0];
}

@end




/*
 * Terminal Suite
 */

@implementation TerminalApplication(TerminalSuite)


- (SBElementArray *) settingsSets
{
	return [self elementArrayWithCode:'tprf'];
}


- (TerminalSettingsSet *) defaultSettings
{
	return (TerminalSettingsSet *) [self propertyWithClass:[TerminalSettingsSet class] code:'tdpr'];
}

- (void) setDefaultSettings: (TerminalSettingsSet *) defaultSettings
{
	[[self propertyWithClass:[TerminalSettingsSet class] code:'tdpr'] setTo:defaultSettings];
}

- (TerminalSettingsSet *) startupSettings
{
	return (TerminalSettingsSet *) [self propertyWithClass:[TerminalSettingsSet class] code:'tspr'];
}

- (void) setStartupSettings: (TerminalSettingsSet *) startupSettings
{
	[[self propertyWithClass:[TerminalSettingsSet class] code:'tspr'] setTo:startupSettings];
}

@end


@implementation TerminalSettingsSet

- (NSInteger) id
{
	id v = [[self propertyWithCode:'ID  '] get];
	return [v integerValue];
}

- (NSString *) name
{
	return [[self propertyWithCode:'pnam'] get];
}

- (void) setName: (NSString *) name
{
	[[self propertyWithCode:'pnam'] setTo:name];
}

- (NSInteger) numberOfRows
{
	id v = [[self propertyWithCode:'crow'] get];
	return [v integerValue];
}

- (void) setNumberOfRows: (NSInteger) numberOfRows
{
	id v = [NSNumber numberWithInteger:numberOfRows];
	[[self propertyWithCode:'crow'] setTo:v];
}

- (NSInteger) numberOfColumns
{
	id v = [[self propertyWithCode:'ccol'] get];
	return [v integerValue];
}

- (void) setNumberOfColumns: (NSInteger) numberOfColumns
{
	id v = [NSNumber numberWithInteger:numberOfColumns];
	[[self propertyWithCode:'ccol'] setTo:v];
}

#if defined(APPKIT_EXTERN)
- (NSColor *) cursorColor
{
	return [[self propertyWithCode:'pcuc'] get];
}

- (void) setCursorColor: (NSColor *) cursorColor
{
	[[self propertyWithCode:'pcuc'] setTo:cursorColor];
}

- (NSColor *) backgroundColor
{
	return [[self propertyWithCode:'pbcl'] get];
}

- (void) setBackgroundColor: (NSColor *) backgroundColor
{
	[[self propertyWithCode:'pbcl'] setTo:backgroundColor];
}

- (NSColor *) normalTextColor
{
	return [[self propertyWithCode:'ptxc'] get];
}

- (void) setNormalTextColor: (NSColor *) normalTextColor
{
	[[self propertyWithCode:'ptxc'] setTo:normalTextColor];
}

- (NSColor *) boldTextColor
{
	return [[self propertyWithCode:'pbtc'] get];
}

- (void) setBoldTextColor: (NSColor *) boldTextColor
{
	[[self propertyWithCode:'pbtc'] setTo:boldTextColor];
}
#endif

- (NSString *) fontName
{
	return [[self propertyWithCode:'font'] get];
}

- (void) setFontName: (NSString *) fontName
{
	[[self propertyWithCode:'font'] setTo:fontName];
}

- (NSInteger) fontSize
{
	id v = [[self propertyWithCode:'ptsz'] get];
	return [v integerValue];
}

- (void) setFontSize: (NSInteger) fontSize
{
	id v = [NSNumber numberWithInteger:fontSize];
	[[self propertyWithCode:'ptsz'] setTo:v];
}

- (BOOL) fontAntialiasing
{
	id v = [[self propertyWithCode:'panx'] get];
	return [v boolValue];
}

- (void) setFontAntialiasing: (BOOL) fontAntialiasing
{
	id v = [NSNumber numberWithBool:fontAntialiasing];
	[[self propertyWithCode:'panx'] setTo:v];
}

- (NSArray<NSString *> *) cleanCommands
{
	return [[self propertyWithCode:'tcln'] get];
}

- (void) setCleanCommands: (NSArray<NSString *> *) cleanCommands
{
	[[self propertyWithCode:'tcln'] setTo:cleanCommands];
}

- (BOOL) titleDisplaysDeviceName
{
	id v = [[self propertyWithCode:'tddn'] get];
	return [v boolValue];
}

- (void) setTitleDisplaysDeviceName: (BOOL) titleDisplaysDeviceName
{
	id v = [NSNumber numberWithBool:titleDisplaysDeviceName];
	[[self propertyWithCode:'tddn'] setTo:v];
}

- (BOOL) titleDisplaysShellPath
{
	id v = [[self propertyWithCode:'tdsp'] get];
	return [v boolValue];
}

- (void) setTitleDisplaysShellPath: (BOOL) titleDisplaysShellPath
{
	id v = [NSNumber numberWithBool:titleDisplaysShellPath];
	[[self propertyWithCode:'tdsp'] setTo:v];
}

- (BOOL) titleDisplaysWindowSize
{
	id v = [[self propertyWithCode:'tdws'] get];
	return [v boolValue];
}

- (void) setTitleDisplaysWindowSize: (BOOL) titleDisplaysWindowSize
{
	id v = [NSNumber numberWithBool:titleDisplaysWindowSize];
	[[self propertyWithCode:'tdws'] setTo:v];
}

- (BOOL) titleDisplaysSettingsName
{
	id v = [[self propertyWithCode:'tdsn'] get];
	return [v boolValue];
}

- (void) setTitleDisplaysSettingsName: (BOOL) titleDisplaysSettingsName
{
	id v = [NSNumber numberWithBool:titleDisplaysSettingsName];
	[[self propertyWithCode:'tdsn'] setTo:v];
}

- (BOOL) titleDisplaysCustomTitle
{
	id v = [[self propertyWithCode:'tdct'] get];
	return [v boolValue];
}

- (void) setTitleDisplaysCustomTitle: (BOOL) titleDisplaysCustomTitle
{
	id v = [NSNumber numberWithBool:titleDisplaysCustomTitle];
	[[self propertyWithCode:'tdct'] setTo:v];
}

- (NSString *) customTitle
{
	return [[self propertyWithCode:'titl'] get];
}

- (void) setCustomTitle: (NSString *) customTitle
{
	[[self propertyWithCode:'titl'] setTo:customTitle];
}



- (void) closeSaving:(TerminalSaveOptions)saving savingIn:(NSURL *)savingIn
{
	[self sendEvent:'core' id:'clos' parameters:'savo', [NSAppleEventDescriptor descriptorWithEnumCode:saving], 'kfil', savingIn, 0];
}

- (void) saveIn:(NSURL *)in_
{
	[self sendEvent:'core' id:'save' parameters:'kfil', in_, 0];
}

- (void) printWithProperties:(NSDictionary *)withProperties printDialog:(BOOL)printDialog
{
	[self sendEvent:'aevt' id:'pdoc' parameters:'prdt', withProperties, 'pdlg', [NSNumber numberWithBool:printDialog], 0];
}

- (void) delete
{
	[self sendEvent:'core' id:'delo' parameters:0];
}

- (void) duplicateTo:(SBObject *)to withProperties:(NSDictionary *)withProperties
{
	[self sendEvent:'core' id:'clon' parameters:'insh', to, 'prdt', withProperties, 0];
}

- (BOOL) exists
{
	id result__ = [self sendEvent:'core' id:'doex' parameters:0];
	return [result__ boolValue];
}

- (void) moveTo:(SBObject *)to
{
	[self sendEvent:'core' id:'move' parameters:'insh', to, 0];
}

@end


@implementation TerminalTab

- (NSInteger) numberOfRows
{
	id v = [[self propertyWithCode:'crow'] get];
	return [v integerValue];
}

- (void) setNumberOfRows: (NSInteger) numberOfRows
{
	id v = [NSNumber numberWithInteger:numberOfRows];
	[[self propertyWithCode:'crow'] setTo:v];
}

- (NSInteger) numberOfColumns
{
	id v = [[self propertyWithCode:'ccol'] get];
	return [v integerValue];
}

- (void) setNumberOfColumns: (NSInteger) numberOfColumns
{
	id v = [NSNumber numberWithInteger:numberOfColumns];
	[[self propertyWithCode:'ccol'] setTo:v];
}

- (NSString *) contents
{
	return [[self propertyWithCode:'pcnt'] get];
}

- (NSString *) history
{
	return [[self propertyWithCode:'hist'] get];
}

- (BOOL) busy
{
	id v = [[self propertyWithCode:'busy'] get];
	return [v boolValue];
}

- (NSArray<NSString *> *) processes
{
	return [[self propertyWithCode:'prcs'] get];
}

- (BOOL) selected
{
	id v = [[self propertyWithCode:'tbsl'] get];
	return [v boolValue];
}

- (void) setSelected: (BOOL) selected
{
	id v = [NSNumber numberWithBool:selected];
	[[self propertyWithCode:'tbsl'] setTo:v];
}

- (BOOL) titleDisplaysCustomTitle
{
	id v = [[self propertyWithCode:'tdct'] get];
	return [v boolValue];
}

- (void) setTitleDisplaysCustomTitle: (BOOL) titleDisplaysCustomTitle
{
	id v = [NSNumber numberWithBool:titleDisplaysCustomTitle];
	[[self propertyWithCode:'tdct'] setTo:v];
}

- (NSString *) customTitle
{
	return [[self propertyWithCode:'titl'] get];
}

- (void) setCustomTitle: (NSString *) customTitle
{
	[[self propertyWithCode:'titl'] setTo:customTitle];
}

- (NSString *) tty
{
	return [[self propertyWithCode:'ttty'] get];
}

- (TerminalSettingsSet *) currentSettings
{
	return (TerminalSettingsSet *) [self propertyWithClass:[TerminalSettingsSet class] code:'tcst'];
}

- (void) setCurrentSettings: (TerminalSettingsSet *) currentSettings
{
	[[self propertyWithClass:[TerminalSettingsSet class] code:'tcst'] setTo:currentSettings];
}

#if defined(APPKIT_EXTERN)
- (NSColor *) cursorColor
{
	return [[self propertyWithCode:'pcuc'] get];
}

- (void) setCursorColor: (NSColor *) cursorColor
{
	[[self propertyWithCode:'pcuc'] setTo:cursorColor];
}

- (NSColor *) backgroundColor
{
	return [[self propertyWithCode:'pbcl'] get];
}

- (void) setBackgroundColor: (NSColor *) backgroundColor
{
	[[self propertyWithCode:'pbcl'] setTo:backgroundColor];
}

- (NSColor *) normalTextColor
{
	return [[self propertyWithCode:'ptxc'] get];
}

- (void) setNormalTextColor: (NSColor *) normalTextColor
{
	[[self propertyWithCode:'ptxc'] setTo:normalTextColor];
}

- (NSColor *) boldTextColor
{
	return [[self propertyWithCode:'pbtc'] get];
}

- (void) setBoldTextColor: (NSColor *) boldTextColor
{
	[[self propertyWithCode:'pbtc'] setTo:boldTextColor];
}
#endif

- (NSArray<NSString *> *) cleanCommands
{
	return [[self propertyWithCode:'tcln'] get];
}

- (void) setCleanCommands: (NSArray<NSString *> *) cleanCommands
{
	[[self propertyWithCode:'tcln'] setTo:cleanCommands];
}

- (BOOL) titleDisplaysDeviceName
{
	id v = [[self propertyWithCode:'tddn'] get];
	return [v boolValue];
}

- (void) setTitleDisplaysDeviceName: (BOOL) titleDisplaysDeviceName
{
	id v = [NSNumber numberWithBool:titleDisplaysDeviceName];
	[[self propertyWithCode:'tddn'] setTo:v];
}

- (BOOL) titleDisplaysShellPath
{
	id v = [[self propertyWithCode:'tdsp'] get];
	return [v boolValue];
}

- (void) setTitleDisplaysShellPath: (BOOL) titleDisplaysShellPath
{
	id v = [NSNumber numberWithBool:titleDisplaysShellPath];
	[[self propertyWithCode:'tdsp'] setTo:v];
}

- (BOOL) titleDisplaysWindowSize
{
	id v = [[self propertyWithCode:'tdws'] get];
	return [v boolValue];
}

- (void) setTitleDisplaysWindowSize: (BOOL) titleDisplaysWindowSize
{
	id v = [NSNumber numberWithBool:titleDisplaysWindowSize];
	[[self propertyWithCode:'tdws'] setTo:v];
}

- (BOOL) titleDisplaysFileName
{
	id v = [[self propertyWithCode:'tdfn'] get];
	return [v boolValue];
}

- (void) setTitleDisplaysFileName: (BOOL) titleDisplaysFileName
{
	id v = [NSNumber numberWithBool:titleDisplaysFileName];
	[[self propertyWithCode:'tdfn'] setTo:v];
}

- (NSString *) fontName
{
	return [[self propertyWithCode:'font'] get];
}

- (void) setFontName: (NSString *) fontName
{
	[[self propertyWithCode:'font'] setTo:fontName];
}

- (NSInteger) fontSize
{
	id v = [[self propertyWithCode:'ptsz'] get];
	return [v integerValue];
}

- (void) setFontSize: (NSInteger) fontSize
{
	id v = [NSNumber numberWithInteger:fontSize];
	[[self propertyWithCode:'ptsz'] setTo:v];
}

- (BOOL) fontAntialiasing
{
	id v = [[self propertyWithCode:'panx'] get];
	return [v boolValue];
}

- (void) setFontAntialiasing: (BOOL) fontAntialiasing
{
	id v = [NSNumber numberWithBool:fontAntialiasing];
	[[self propertyWithCode:'panx'] setTo:v];
}



- (void) closeSaving:(TerminalSaveOptions)saving savingIn:(NSURL *)savingIn
{
	[self sendEvent:'core' id:'clos' parameters:'savo', [NSAppleEventDescriptor descriptorWithEnumCode:saving], 'kfil', savingIn, 0];
}

- (void) saveIn:(NSURL *)in_
{
	[self sendEvent:'core' id:'save' parameters:'kfil', in_, 0];
}

- (void) printWithProperties:(NSDictionary *)withProperties printDialog:(BOOL)printDialog
{
	[self sendEvent:'aevt' id:'pdoc' parameters:'prdt', withProperties, 'pdlg', [NSNumber numberWithBool:printDialog], 0];
}

- (void) delete
{
	[self sendEvent:'core' id:'delo' parameters:0];
}

- (void) duplicateTo:(SBObject *)to withProperties:(NSDictionary *)withProperties
{
	[self sendEvent:'core' id:'clon' parameters:'insh', to, 'prdt', withProperties, 0];
}

- (BOOL) exists
{
	id result__ = [self sendEvent:'core' id:'doex' parameters:0];
	return [result__ boolValue];
}

- (void) moveTo:(SBObject *)to
{
	[self sendEvent:'core' id:'move' parameters:'insh', to, 0];
}

@end


