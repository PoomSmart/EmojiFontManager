#import "../PS.h"
#import "../PSPrefs.x"

NSString *tweakIdentifier = @"com.PS.EmojiFontManager";
NSString *selectedFontKey = @"selectedFont";
NSString *defaultName = @"Default";
NSString *fontsPath() { return isiOS7Up ? @"/Library/Themes/EmojiFontManager" : @"/User/Library/Themes/EmojiFontManager"; }

#ifdef TWEAK

NSString *selectedFont;

HaveCallback() {
	GetPrefs()
	GetObject2(selectedFont, defaultName)
}

#endif
