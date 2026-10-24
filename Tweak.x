#define CHECK_TARGET
#define CHECK_WHITELIST
#import "Prefs.h"
#import "../../PSPrefs/PSPrefs.x"
#import <CoreGraphics/CoreGraphics.h>
#import <CoreText/CoreText.h>
#import <HBLog.h>
#import <dlfcn.h>

typedef CFStringRef (*EFMFontCopyPostScriptName)(CTFontRef);
typedef CGFloat (*EFMFontGetSize)(CTFontRef);
typedef CFStringRef (*EFMCopyCGFontName)(CGFontRef);
typedef CTFontRef (*EFMFontCreateWithGraphicsFont)(CGFontRef, CGFloat, const CGAffineTransform *, CTFontDescriptorRef);

static EFMFontCopyPostScriptName fontCopyPostScriptName;
static EFMFontGetSize fontGetSize;
static EFMCopyCGFontName copyCGFontName;
static EFMFontCreateWithGraphicsFont fontCreateWithGraphicsFont;
static CTFontRef cachedFallbackFont;
static CFStringRef cachedFallbackName;
static CGFloat cachedFallbackSize;

extern CFArrayRef CGFontCreateFontsWithPath(CFStringRef);

static CTFontRef fontFromEmojiFile(CFStringRef path, CFStringRef wantedName, CGFloat size) {
    if (!path || !fontCreateWithGraphicsFont || !copyCGFontName)
        return NULL;
    CFArrayRef fonts = CGFontCreateFontsWithPath(path);
    if (!fonts)
        return NULL;
    CTFontRef created = NULL;
    CFIndex count = CFArrayGetCount(fonts);
    CGFontRef fallback = count > 0 ? (CGFontRef)CFArrayGetValueAtIndex(fonts, 0) : NULL;
    for (CFIndex i = 0; i < count; i++) {
        CGFontRef cg = (CGFontRef)CFArrayGetValueAtIndex(fonts, i);
        CFStringRef name = copyCGFontName(cg);
        BOOL match = wantedName && name && CFEqual(name, wantedName);
        if (name)
            CFRelease(name);
        if (match) {
            fallback = cg;
            break;
        }
    }
    if (fallback)
        created = fontCreateWithGraphicsFont(fallback, size, NULL, NULL);
    CFRelease(fonts);
    return created;
}

static BOOL emojiFontName(CFStringRef name) {
    return name && (CFEqual(name, CFSTR("AppleColorEmoji")) || CFEqual(name, CFSTR(".AppleColorEmojiUI")));
}

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

%group EmojiFallback

CTFontRef (*GetFallbackFont)(void *, void *, CTFontDescriptorRef, unsigned) = NULL;
%hookf(CTFontRef, GetFallbackFont, void *self, void *baseFont, CTFontDescriptorRef descriptor, unsigned flags) {
    CTFontRef font = %orig;
    CFStringRef path = getNewFontPath();
    if (!font || !path || !fontCopyPostScriptName || !fontGetSize)
        return font;
    CFStringRef name = fontCopyPostScriptName(font);
    if (!emojiFontName(name)) {
        if (name)
            CFRelease(name);
        return font;
    }
    CGFloat size = fontGetSize(font);
    if (cachedFallbackFont && cachedFallbackName && cachedFallbackSize == size && CFEqual(cachedFallbackName, name)) {
        CFRelease(name);
        return cachedFallbackFont;
    }
    CTFontRef created = fontFromEmojiFile(path, name, size);
    if (!created) {
        CFRelease(name);
        return font;
    }
    if (cachedFallbackFont)
        CFRelease(cachedFallbackFont);
    if (cachedFallbackName)
        CFRelease(cachedFallbackName);
    cachedFallbackFont = created;
    cachedFallbackName = name;
    cachedFallbackSize = size;
    HBLogDebug(@"EFM: Emoji font overridden at GetFallbackFont");
    return cachedFallbackFont;
}

%end

%ctor {
    if (!_isTarget(TargetTypeApps | TargetTypeGenericExtensions, @[@"com.apple.WebKit.WebContent", @"chronod"], nil)) return;
    static const char *const gsFontPaths[] = {
        "/System/Library/PrivateFrameworks/FontServices.framework/libGSFont.dylib",
        "/System/Library/PrivateFrameworks/GraphicsServices.framework/libGSFont.dylib",
    };
    for (size_t i = 0; i < sizeof(gsFontPaths) / sizeof(gsFontPaths[0]); i++) {
        if (!dlopen(gsFontPaths[i], RTLD_LAZY))
            continue;
        MSImageRef gsFontRef = MSGetImageByName(gsFontPaths[i]);
        GSFontCopyFontFilePath = (const void (*)(const void *))MSFindSymbol(gsFontRef, "_GSFontCopyFontFilePath");
        if (GSFontCopyFontFilePath != NULL) {
            HBLogDebug(@"EFM: Hooking GSFontCopyFontFilePath (%s)", gsFontPaths[i]);
            %init(GSFontPath);
            break;
        }
    }
    const char *fontParserPath = "/System/Library/PrivateFrameworks/FontServices.framework/libFontParser.dylib";
    if (dlopen(fontParserPath, RTLD_LAZY)) {
        MSImageRef fontParserRef = MSGetImageByName(fontParserPath);
        FPFontCreateFontsWithPath = (CFArrayRef (*)(CFStringRef))MSFindSymbol(fontParserRef, "_FPFontCreateFontsWithPath");
        FPFontCreateWithPathAndName = (FPFontRef (*)(CFStringRef, CFStringRef))MSFindSymbol(fontParserRef, "_FPFontCreateWithPathAndName");
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
    if (dlopen("/System/Library/Frameworks/CoreText.framework/CoreText", RTLD_LAZY)) {
        MSImageRef coreTextImage = MSGetImageByName("/System/Library/Frameworks/CoreText.framework/CoreText");
        fontCopyPostScriptName = (EFMFontCopyPostScriptName)_PSFindSymbolCallable(coreTextImage, "_CTFontCopyPostScriptName");
        fontGetSize = (EFMFontGetSize)_PSFindSymbolCallable(coreTextImage, "_CTFontGetSize");
        fontCreateWithGraphicsFont = (EFMFontCreateWithGraphicsFont)_PSFindSymbolCallable(coreTextImage, "_CTFontCreateWithGraphicsFont");
        dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY);
        MSImageRef coreGraphicsImage = MSGetImageByName("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics");
        copyCGFontName = (EFMCopyCGFontName)_PSFindSymbolCallable(coreGraphicsImage, "_CGFontCopyPostScriptName");
        GetFallbackFont = (CTFontRef (*)(void *, void *, CTFontDescriptorRef, unsigned))_PSFindSymbolReadable(coreTextImage, "__ZNK12TFontCascade15GetFallbackFontEPK9TBaseFontPK18__CTFontDescriptorj");
        if (GetFallbackFont) {
            HBLogDebug(@"EFM: Hooking GetFallbackFont");
            %init(EmojiFallback);
        }
    }
}
