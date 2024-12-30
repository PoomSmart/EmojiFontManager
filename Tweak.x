#define CHECK_TARGET
#define CHECK_WHITELIST
#import "Prefs.h"
#import "../../PSPrefs/PSPrefs.x"
#import <CoreGraphics/CoreGraphics.h>
#import <HBLog.h>
#import <dlfcn.h>

typedef const struct __FPFont *FPFontRef;

NSString *selectedFont;
CFStringRef newFontPath;

static NSString *getPath(NSString *font) {
    if (!font) {
        HBLogDebug(@"EFM: Font name is nil");
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
            HBLogDebug(@"EFM: New emoji font: %@", newPath);
            return (__bridge CFStringRef)newPath;
        }
    }
    HBLogDebug(@"EFM: Use system emoji font");
    return NULL;
}

%group Path

extern CFArrayRef CGFontCreateFontsWithPath(CFStringRef);
%hookf(CFArrayRef, CGFontCreateFontsWithPath, CFStringRef path) {
    if (path && CFStringFind(path, CFSTR("AppleColorEmoji"), kCFCompareCaseInsensitive).location != kCFNotFound) {
        CFStringRef newFontPath = getNewFontPath();
        if (newFontPath) {
            HBLogDebug(@"EFM: Emoji font overridden at CGFontCreateFontsWithPath");
            return %orig(newFontPath);
        }
    }
    return %orig(path);
}

%end

%group CCF

extern CFURLRef CFURLCreateCopyAppendingPathExtension(CFAllocatorRef, CFURLRef, CFStringRef);
%hookf(CFURLRef, CFURLCreateCopyAppendingPathExtension, CFAllocatorRef allocator, CFURLRef url, CFStringRef extension) {
    if (url && CFStringEqual(extension, CFSTR("ccf")) && ![selectedFont isEqualToString:defaultName]) {
        CFStringRef newFontPath = getNewFontPath();
        if (newFontPath) {
            CFStringRef path = CFURLCopyPath(url);
            if (CFStringFind(path, CFSTR("/System/Library/Fonts/Core/AppleColorEmoji"), kCFCompareCaseInsensitive).location != kCFNotFound)
                extension = CFSTR("null");
            if (path) CFRelease(path);
        }
    }
    return %orig(allocator, url, extension);
}

%end

%group FontParserPath

CFArrayRef (*FPFontCreateFontsWithPath)(CFStringRef) = NULL;
%hookf(CFArrayRef, FPFontCreateFontsWithPath, CFStringRef path) {
    if (path && CFStringFind(path, CFSTR("AppleColorEmoji"), kCFCompareCaseInsensitive).location != kCFNotFound) {
        CFStringRef newFontPath = getNewFontPath();
        if (newFontPath) {
            HBLogDebug(@"EFM: Emoji font overridden at FPFontCreateFontsWithPath");
            return %orig(newFontPath);
        }
    }
    return %orig(path);
}

%end

%group FontParserPathAndName

FPFontRef (*FPFontCreateWithPathAndName)(CFStringRef path, CFStringRef name) = NULL;
%hookf(FPFontRef, FPFontCreateWithPathAndName, CFStringRef path, CFStringRef name) {
    if (name && (CFStringEqual(name, CFSTR("AppleColorEmoji")) || CFStringEqual(name, CFSTR(".AppleColorEmojiUI")))) {
        CFStringRef newFontPath = getNewFontPath();
        if (newFontPath) {
            HBLogDebug(@"EFM: Emoji font overridden at FPFontCreateWithPathAndName");
            return %orig(newFontPath, name);
        }
    }
    return %orig(path, name);
}

%end

// %group OT

// NSDictionary *(*GSFontGetCacheDictionary)() = NULL;
// %hookf(NSDictionary *, GSFontGetCacheDictionary) {
//     NSMutableDictionary *dict = (NSMutableDictionary *)CFBridgingRelease(CFPropertyListCreateDeepCopy(kCFAllocatorDefault, (CFDictionaryRef)%orig, kCFPropertyListMutableContainersAndLeaves));
//     CFStringRef newFontPath = getNewFontPath();
//     // dict[@"Attrs"][@"AppleColorEmoji"][@"CTFontHasOTFeatures"] = @(YES);
//     dict[@"GSFontCache"][@"CGCache"][@"Names"][@"AppleColorEmoji"] =
//         dict[@"GSFontCache"][@"CGCache"][@"Names"][@".AppleColorEmojiUI"] =
//         dict[@"GSFontCache"][@"__PSToFileName"][@"AppleColorEmoji"] =
//         dict[@"GSFontCache"][@"__PSToFileName"][@".AppleColorEmojiUI"] =
//         dict[@"GSFontCache"][@"__PSToFileNameHighRes"][@"AppleColorEmoji"] =
//         dict[@"GSFontCache"][@"__PSToFileNameHighRes"][@".AppleColorEmojiUI"] = (__bridge NSString *)newFontPath;
//     return dict;
// }

// NSDictionary *(*GSFontGetCacheData)(NSString *) = NULL;
// %hookf(NSDictionary *, GSFontGetCacheData, NSString *entry) {
//     NSDictionary *dict = %orig(entry);
//     if ([entry isEqualToString:@"GSFontCache"]) {
//         NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithDictionary:dict];
//         CFStringRef newFontPath = getNewFontPath();
//         newDict[@"CGCache"][@"Names"][@"AppleColorEmoji"] =
//             newDict[@"CGCache"][@"Names"][@".AppleColorEmojiUI"] =
//             newDict[@"__PSToFileName"][@"AppleColorEmoji"] =
//             newDict[@"__PSToFileName"][@".AppleColorEmojiUI"] =
//             newDict[@"__PSToFileNameHighRes"][@"AppleColorEmoji"] =
//             newDict[@"__PSToFileNameHighRes"][@".AppleColorEmojiUI"] = (__bridge NSString *)newFontPath;
//         return newDict;
//     }
//     return dict;
// }

// %end

%ctor {
    if (_isTarget(TargetTypeApps | TargetTypeGenericExtensions, @[@"com.apple.WebKit.WebContent"], nil)) {
        const char *fontParserPath = "/System/Library/PrivateFrameworks/FontServices.framework/libFontParser.dylib";
        if (dlopen(fontParserPath, RTLD_LAZY)) {
            MSImageRef fontParserRef = MSGetImageByName(fontParserPath);
            FPFontCreateFontsWithPath = MSFindSymbol(fontParserRef, "_FPFontCreateFontsWithPath");
            FPFontCreateWithPathAndName = MSFindSymbol(fontParserRef, "_FPFontCreateWithPathAndName");
            if (FPFontCreateFontsWithPath != NULL) {
                HBLogDebug(@"EFM: Hooking FPFontCreateFontsWithPath");
                %init(FontParserPath);
            }
            if (FPFontCreateWithPathAndName != NULL) {
                HBLogDebug(@"EFM: Hooking FPFontCreateWithPathAndName");
                %init(FontParserPathAndName);
            }
        } else {
            HBLogDebug(@"EFM: Hooking CGFontCreateFontsWithPath");
            %init(Path);
        }
        // const char *gsFontParserPath = "/System/Library/PrivateFrameworks/FontServices.framework/libGSFont.dylib";
        // if (dlopen(gsFontParserPath, RTLD_NOW)) {
        //     MSImageRef gsFontParserRef = MSGetImageByName(gsFontParserPath);
        //     GSFontGetCacheData = MSFindSymbol(gsFontParserRef, "_GSFontGetCacheData");
        //     GSFontGetCacheDictionary = MSFindSymbol(gsFontParserRef, "_GSFontGetCacheDictionary");
        //     if (GSFontGetCacheData != NULL && GSFontGetCacheDictionary != NULL) {
        //         HBLogDebug(@"EFM: Init libGSFont hooks");
        //         %init(OT);
        //     }
        // }
        if (IS_IOS_BETWEEN_EEX(iOS_8_3, iOS_11_0)) {
            %init(CCF);
        }
    }
}
