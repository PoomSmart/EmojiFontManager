#define CHECK_TARGET
#define CHECK_WHITELIST
#import "Prefs.h"
#import "../PSPrefs/PSPrefs.x"
#import <CoreGraphics/CoreGraphics.h>
#import <HBLog.h>
#import <dlfcn.h>

NSString *selectedFont;
NSString *newFontPath;

static NSString *getPath(NSString *font) {
    if (font == nil) {
        HBLogError(@"font name is nil");
        return nil;
    }
    return [NSString stringWithFormat:@"%@/%@/AppleColorEmoji@2x.ttc", fontsPath, font];
}

static NSString *getNewFontPath() {
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
            return newPath;
        }
    }
    HBLogError(@"Could not get emoji font");
    return nil;
}

%group Path

extern CFMutableArrayRef CGFontCreateFontsWithPath(CFStringRef);
%hookf(CFMutableArrayRef, CGFontCreateFontsWithPath, CFStringRef const path) {
    if (path && newFontPath && CFStringFind(path, CFSTR("AppleColorEmoji"), kCFCompareCaseInsensitive).location != kCFNotFound) {
        HBLogDebug(@"Emoji font overridden at CGFontCreateFontsWithPath");
        return %orig((__bridge CFStringRef const)newFontPath);
    }
    return %orig(path);
}

%end

%group PathAndName

CGFontRef (*CGFontCreateWithPathAndName)(CFStringRef path, CFStringRef name) = NULL;
%hookf(CGFontRef, CGFontCreateWithPathAndName, CFStringRef path, CFStringRef name) {
    if (name && newFontPath && (CFStringEqual(name, CFSTR("AppleColorEmoji")) || CFStringEqual(name, CFSTR(".AppleColorEmojiUI")))) {
        HBLogDebug(@"Emoji font overridden at CGFontCreateWithPathAndName");
        return %orig((__bridge CFStringRef)newFontPath, name);
    }
    return %orig(path, name);
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

CFMutableArrayRef (*FPFontCreateFontsWithPath)(CFStringRef) = NULL;
%hookf(CFMutableArrayRef, FPFontCreateFontsWithPath, CFStringRef path) {
    if (path && newFontPath && CFStringFind(path, CFSTR("AppleColorEmoji"), kCFCompareCaseInsensitive).location != kCFNotFound) {
        HBLogDebug(@"Emoji font overridden at FPFontCreateFontsWithPath");
        return %orig((__bridge CFStringRef const)newFontPath);
    }
    return %orig(path);
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
        MSImageRef cgRef = MSGetImageByName("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics");
        CGFontCreateWithPathAndName = MSFindSymbol(cgRef, "_CGFontCreateWithPathAndName");
        if (CGFontCreateWithPathAndName) {
            HBLogDebug(@"Init CGFontCreateWithPathAndName hook");
            %init(PathAndName);
        }
        const char *fontParserPath = "/System/Library/PrivateFrameworks/FontServices.framework/libFontParser.dylib";
        if (dlopen(fontParserPath, RTLD_NOW)) {
            MSImageRef fontParserRef = MSGetImageByName(fontParserPath);
            FPFontCreateFontsWithPath = MSFindSymbol(fontParserRef, "_FPFontCreateFontsWithPath");
            if (FPFontCreateFontsWithPath != NULL) {
                HBLogDebug(@"Init FPFontCreateFontsWithPath hook");
                %init(FontParser);
            }
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
        %init(Path);
    }
}
