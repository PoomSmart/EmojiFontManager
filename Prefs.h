#import "../PS.h"
#import <Cephei/HBPreferences.h>

#define tweakIdentifier @"com.PS.EmojiFontManager"
#define selectedFontKey @"selectedFont"
#define defaultName @"Default"
#define fontsPath (isiOS7Up ? [[@"/Library/Themes/EmojiFontManager" retain] autorelease] : [[@"/User/Library/Themes/EmojiFontManager" retain] autorelease])

NSString *getPath(NSString *font) {
    if (font == nil) {
        HBLogError(@"font name is nil");
        return nil;
    }
    NSString *format = isiOS10Up ? @"%@/%@/AppleColorEmoji@2x.ttc" : @"%@/%@/AppleColorEmoji@2x.ttf";
    return [NSString stringWithFormat:format, fontsPath, font];
}