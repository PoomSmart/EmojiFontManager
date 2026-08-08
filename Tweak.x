#define CHECK_TARGET
#define CHECK_WHITELIST
#import "Prefs.h"
#import "../../PSPrefs/PSPrefs.x"
#import <CoreGraphics/CoreGraphics.h>
#import <HBLog.h>
#import <dlfcn.h>

typedef const struct __FPFont *FPFontRef;

NSString *selectedFont;

static NSString *getPath(NSString *font) {
    if (!font) {
        HBLogDebug(@"EFM: Font name is nil");
        return nil;
    }
    return [NSString stringWithFormat:@"%@/%@/AppleColorEmoji@2x.ttc", fontsPath, font];
}

static CFStringRef getNewFontPath() {
    CFStringRef value = (CFStringRef)CFPreferencesCopyAppValue(selectedFontKey, domain);
    if (value == NULL)
        value = (CFStringRef)CFPreferencesCopyValue(selectedFontKey, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (value == NULL) {
        GetPrefs();
        if (selectedFont == nil)
            selectedFont = PSSettings[(__bridge NSString *)selectedFontKey];
    } else if (selectedFont == nil) {
        selectedFont = (__bridge_transfer NSString *)value;
        value = NULL;
    }
    if (value)
        CFRelease(value);
    if (selectedFont == nil)
        selectedFont = defaultName;
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

#if !__arm64e__

%group CCF

extern CFURLRef CFURLCreateCopyAppendingPathExtension(CFAllocatorRef, CFURLRef, CFStringRef);
%hookf(CFURLRef, CFURLCreateCopyAppendingPathExtension, CFAllocatorRef allocator, CFURLRef url, CFStringRef extension) {
    if (url && CFStringEqual(extension, CFSTR("ccf")) && ![selectedFont isEqualToString:defaultName]) {
        CFStringRef newFontPath = getNewFontPath();
        if (newFontPath) {
            CFStringRef path = CFURLCopyPath(url);
            if (path) {
                if (CFStringFind(path, CFSTR("/System/Library/Fonts/Core/AppleColorEmoji"), kCFCompareCaseInsensitive).location != kCFNotFound)
                    extension = CFSTR("null");
                CFRelease(path);
            }
        }
    }
    return %orig(allocator, url, extension);
}

%end

#endif

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

%group GSFontPath

const void (*GSFontCopyFontFilePath)(const void *psName) = NULL;
%hookf(const void *, GSFontCopyFontFilePath, const void *psName) {
    if (psName && (CFStringEqual((CFStringRef)psName, CFSTR("AppleColorEmoji"))
                || CFStringEqual((CFStringRef)psName, CFSTR(".AppleColorEmojiUI")))) {
        CFStringRef newFontPath = getNewFontPath();
        if (newFontPath) {
            HBLogDebug(@"EFM: Emoji font overridden at GSFontCopyFontFilePath");
            return CFRetain(newFontPath);
        }
    }
    return %orig(psName);
}

%end

%ctor {
    if (_isTarget(TargetTypeApps | TargetTypeGenericExtensions, @[@"com.apple.WebKit.WebContent"], nil)) {
        static const char *const gsFontPaths[] = {
            "/System/Library/PrivateFrameworks/FontServices.framework/libGSFont.dylib",
            "/System/Library/PrivateFrameworks/GraphicsServices.framework/libGSFont.dylib",
        };
        for (size_t i = 0; i < sizeof(gsFontPaths) / sizeof(gsFontPaths[0]); i++) {
            if (!dlopen(gsFontPaths[i], RTLD_LAZY))
                continue;
            MSImageRef gsFontRef = MSGetImageByName(gsFontPaths[i]);
            GSFontCopyFontFilePath = MSFindSymbol(gsFontRef, "_GSFontCopyFontFilePath");
            if (GSFontCopyFontFilePath != NULL) {
                HBLogDebug(@"EFM: Hooking GSFontCopyFontFilePath (%s)", gsFontPaths[i]);
                %init(GSFontPath);
                break;
            }
        }
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
#if !__arm64e__
        if (IS_IOS_BETWEEN_EEX(iOS_8_3, iOS_11_0)) {
            %init(CCF);
        }
#endif
    }
}
