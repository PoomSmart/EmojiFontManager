#define CHECK_TARGET
#define CHECK_EXCEPTIONS
#import "Prefs.h"
#import "../PS.h"

static NSString *selectedFont;

static NSString *getPath(NSString *font) {
    if (font == nil) {
        HBLogError(@"font name is nil");
        return nil;
    }
    NSString *format = IS_IOS_OR_NEWER(iOS_10_0) ? @"%@/%@/AppleColorEmoji@2x.ttc" : @"%@/%@/AppleColorEmoji@2x.ttf";
    return [NSString stringWithFormat:format, fontsPath, font];
}

static NSString *getNewFontPath() {
    const void *value = CFPreferencesCopyAppValue(selectedFontKey, domain);
    selectedFont = value ? CFBridgingRelease(value) : defaultName;
    NSString *newPath = getPath(selectedFont);
    if (newPath && !stringEqual(newPath, defaultName)) {
        BOOL exist = fileExist(newPath);
        if (!exist)
            exist = fileExist(newPath = [newPath stringByReplacingOccurrencesOfString:@"ttf" withString:@"ttc"]);
        if (exist) {
            HBLogDebug(@"New emoji font path: %@", newPath);
            return newPath;
        }
    }
    return nil;
}

%group Path

extern "C" CFMutableArrayRef CGFontCreateFontsWithPath(CFStringRef);
%hookf(CFMutableArrayRef, CGFontCreateFontsWithPath, CFStringRef const path) {
    if (path && CFStringFind(path, CFSTR("AppleColorEmoji"), kCFCompareCaseInsensitive).location != kCFNotFound) {
        NSString *newPath = getNewFontPath();
        if (newPath)
            return %orig((__bridge CFStringRef const)newPath);
    }
    return %orig(path);
}

%end

%group PathAndName

CGFontRef (*CGFontCreateWithPathAndName)(CFStringRef path, CFStringRef name) = NULL;
%hookf(CGFontRef, CGFontCreateWithPathAndName, CFStringRef path, CFStringRef name) {
    if (name && (CFStringEqual(name, CFSTR("AppleColorEmoji")) || CFStringEqual(name, CFSTR(".AppleColorEmojiUI")))) {
        NSString *newPath = getNewFontPath();
        if (newPath)
            return %orig((__bridge CFStringRef)newPath, name);
    }
    return %orig(path, name);
}

%end

%group iOS83Up

extern "C" CFURLRef CFURLCreateCopyAppendingPathExtension(CFAllocatorRef, CFURLRef, CFStringRef);
%hookf(CFURLRef, CFURLCreateCopyAppendingPathExtension, CFAllocatorRef allocator, CFURLRef url, CFStringRef extension) {
    if (url && CFStringEqual(extension, CFSTR("ccf")) && !stringEqual(selectedFont, defaultName)) {
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
    if (path && CFStringFind(path, CFSTR("AppleColorEmoji"), kCFCompareCaseInsensitive).location != kCFNotFound) {
        NSString *newPath = getNewFontPath();
        if (newPath)
            return %orig((__bridge CFStringRef const)newPath);
    }
    return %orig(path);
}

%end

%ctor {
    if (_isTarget(TargetTypeApps | TargetTypeGenericExtensions, @[@"com.apple.WebKit.WebContent"])) {
        MSImageRef cgRef = MSGetImageByName("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics");
        CGFontCreateWithPathAndName = (CGFontRef (*)(CFStringRef, CFStringRef))_PSFindSymbolCallable(cgRef, "_CGFontCreateWithPathAndName");
        if (CGFontCreateWithPathAndName) {
            HBLogDebug(@"Init CGFontCreateWithPathAndName hook");
            %init(PathAndName);
        }
        const char *fontParserPath = "/System/Library/PrivateFrameworks/FontServices.framework/libFontParser.dylib";
        if (dlopen(fontParserPath, RTLD_LAZY)) {
            MSImageRef fontParserRef = MSGetImageByName(fontParserPath);
            FPFontCreateFontsWithPath = (CFMutableArrayRef (*)(CFStringRef))_PSFindSymbolCallable(fontParserRef, "_FPFontCreateFontsWithPath");
            if (FPFontCreateFontsWithPath != NULL) {
                HBLogDebug(@"Init FPFontCreateFontsWithPath hook");
                %init(FontParser);
            }
        }
        if (isiOS83Up) {
            %init(iOS83Up);
        }
        %init(Path);
    }
}
