#import "../PS.h"
#import <Cephei/HBPreferences.h>

#define tweakIdentifier @"com.PS.EmojiFontManager"
#define selectedFontKey @"selectedFont"
#define defaultName @"Default"
#define fontsPath [[@"/Library/Themes/EmojiFontManager" retain] autorelease]

NSString *getPath(NSString *font) {
    if (font == nil) {
        HBLogError(@"font name is nil");
        return nil;
    }
    NSString *format = IS_IOS_OR_NEWER(iOS_10_0) ? @"%@/%@/AppleColorEmoji@2x.ttc" : @"%@/%@/AppleColorEmoji@2x.ttf";
    return [NSString stringWithFormat:format, fontsPath, font];
}