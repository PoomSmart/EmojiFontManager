#define CHECK_TARGET
#define CHECK_WHITELIST
#import "Prefs.h"
#import "../../PSPrefs/PSPrefs.x"
#import <CoreGraphics/CoreGraphics.h>
#import <HBLog.h>
#import <dlfcn.h>

NSString *selectedFont;
static CFStringRef newFontPath;

static NSString *getPath(NSString *font) {
    if (!font) {
        HBLogError(@"font name is nil");
        return nil;
    }
    return [NSString stringWithFormat:@"%@/%@/AppleColorEmoji@2x.ttc", fontsPath, font];
}

static CFStringRef getNewFontPath() {
    const void *value = CFPreferencesCopyAppValue(selectedFontKey, domain);
    if (value == NULL)
        value = CFPreferencesCopyValue(selectedFontKey, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (value == NULL) {
        GetPrefs();
        selectedFont = PSSettings[(__bridge NSString *)selectedFontKey];
    }
    if (selectedFont == nil)
        selectedFont = value ? (__bridge NSString *)value : defaultName;
    NSString *newPath = getPath(selectedFont);
    if (newPath && ![newPath isEqualToString:defaultName]) {
        BOOL exist = fileExist(newPath);
        if (!exist)
            exist = fileExist(newPath = [newPath stringByReplacingOccurrencesOfString:@"ttc" withString:@"ttf"]);
        if (exist) {
            HBLogDebug(@"New emoji font: %@", newPath);
            return (__bridge CFStringRef)newPath;
        }
    }
    HBLogInfo(@"Use system emoji font");
    return NULL;
}

%group Path

extern CFArrayRef CGFontCreateFontsWithPath(CFStringRef);
%hookf(CFArrayRef, CGFontCreateFontsWithPath, CFStringRef path) {
    if (path && newFontPath && CFStringFind(path, CFSTR("AppleColorEmoji"), kCFCompareCaseInsensitive).location != kCFNotFound) {
        HBLogDebug(@"Emoji font overridden at CGFontCreateFontsWithPath");
        return %orig(newFontPath);
    }
    return %orig(path);
}

%end

%group CCF

extern CFURLRef CFURLCreateCopyAppendingPathExtension(CFAllocatorRef, CFURLRef, CFStringRef);
%hookf(CFURLRef, CFURLCreateCopyAppendingPathExtension, CFAllocatorRef allocator, CFURLRef url, CFStringRef extension) {
    if (url && newFontPath && CFStringEqual(extension, CFSTR("ccf")) && ![selectedFont isEqualToString:defaultName]) {
        CFStringRef path = CFURLCopyPath(url);
        if (CFStringFind(path, CFSTR("/System/Library/Fonts/Core/AppleColorEmoji"), kCFCompareCaseInsensitive).location != kCFNotFound)
            extension = CFSTR("null");
        if (path) CFRelease(path);
    }
    return %orig(allocator, url, extension);
}

%end

%group FontParser

CFArrayRef (*FPFontCreateFontsWithPath)(CFStringRef) = NULL;
%hookf(CFArrayRef, FPFontCreateFontsWithPath, CFStringRef path) {
    if (path && newFontPath && CFStringFind(path, CFSTR("AppleColorEmoji"), kCFCompareCaseInsensitive).location != kCFNotFound) {
        HBLogDebug(@"Emoji font overridden at FPFontCreateFontsWithPath");
        return %orig(newFontPath);
    }
    return %orig(path);
}

CGFontRef (*FPFontCreateWithPathAndName)(CFStringRef path, CFStringRef name) = NULL;
%hookf(CGFontRef, FPFontCreateWithPathAndName, CFStringRef path, CFStringRef name) {
    if (name && newFontPath && (CFStringEqual(name, CFSTR("AppleColorEmoji")) || CFStringEqual(name, CFSTR(".AppleColorEmojiUI")))) {
        HBLogDebug(@"Emoji font overridden at FPFontCreateWithPathAndName");
        return %orig(newFontPath, name);
    }
    return %orig(path, name);
}

%end

// %group Legacy

// CFStringRef (*_CTGetEmojiFontName)(int) = NULL;
// %hookf(CFStringRef, _CTGetEmojiFontName, int arg1) {
//     return CFSTR("AppleColorEmoji");
// }

// %end

// %group OT

// NSDictionary *(*GSFontGetCacheDictionary)() = NULL;
// %hookf(NSDictionary *, GSFontGetCacheDictionary) {
//     NSMutableDictionary *dict = (NSMutableDictionary *)CFBridgingRelease(CFPropertyListCreateDeepCopy(kCFAllocatorDefault, (CFDictionaryRef)%orig, kCFPropertyListMutableContainersAndLeaves));
//     dict[@"Attrs"][@"AppleColorEmoji"][@"CTFontHasOTFeatures"] = @(YES);
//     dict[@"GSFontCache"][@"CGCache"][@"Names"][@"AppleColorEmoji"] =
//         dict[@"GSFontCache"][@"CGCache"][@"Names"][@".AppleColorEmojiUI"] =
//         dict[@"GSFontCache"][@"__PSToFileName"][@"AppleColorEmoji"] =
//         dict[@"GSFontCache"][@"__PSToFileName"][@".AppleColorEmojiUI"] =
//         dict[@"GSFontCache"][@"__PSToFileNameHighRes"][@"AppleColorEmoji"] =
//         dict[@"GSFontCache"][@"__PSToFileNameHighRes"][@".AppleColorEmojiUI"] = newFontPath;
//     return dict;
// }

// %end

%ctor {
    if (_isTarget(TargetTypeApps | TargetTypeGenericExtensions, @[@"com.apple.WebKit.WebContent"], nil)) {
        newFontPath = getNewFontPath();
        const char *fontParserPath = "/System/Library/PrivateFrameworks/FontServices.framework/libFontParser.dylib";
        if (dlopen(fontParserPath, RTLD_NOW)) {
            MSImageRef fontParserRef = MSGetImageByName(fontParserPath);
            FPFontCreateFontsWithPath = MSFindSymbol(fontParserRef, "_FPFontCreateFontsWithPath");
            FPFontCreateWithPathAndName = MSFindSymbol(fontParserRef, "_FPFontCreateWithPathAndName");
            if (FPFontCreateFontsWithPath != NULL && FPFontCreateWithPathAndName != NULL) {
                HBLogDebug(@"Init libFontParser hooks");
                %init(FontParser);
            }
        } else {
            %init(Path);
        }
        // const char *gsFontParserPath = "/System/Library/PrivateFrameworks/FontServices.framework/libGSFont.dylib";
        // if (dlopen(gsFontParserPath, RTLD_NOW)) {
        //     MSImageRef gsFontParserRef = MSGetImageByName(gsFontParserPath);
        //     GSFontGetCacheDictionary = MSFindSymbol(gsFontParserRef, "_GSFontGetCacheDictionary");
        //     if (GSFontGetCacheDictionary != NULL) {
        //         HBLogDebug(@"Init GSFontGetCacheDictionary hook");
        //         %init(OT);
        //     }
        // }
        // MSImageRef ctRef = MSGetImageByName("/System/Library/Frameworks/CoreText.framework/CoreText");
        // _CTGetEmojiFontName = MSFindSymbol(ctRef, "__CTGetEmojiFontName");
        // if (_CTGetEmojiFontName != NULL) {
        //     %init(Legacy);
        // }
        if (IS_IOS_OR_NEWER(iOS_8_3)) {
            %init(CCF);
        }
    }
}
