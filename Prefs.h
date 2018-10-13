#import "../PS.h"
#import <Cephei/HBPreferences.h>

#define tweakIdentifier @"com.PS.EmojiFontManager"
#define selectedFontKey @"selectedFont"
#define defaultName @"Default"
#define fontsPath (isiOS7Up ? @"/Library/Themes/EmojiFontManager" : @"/User/Library/Themes/EmojiFontManager")