#define CHECK_TARGET
#define TWEAK
#import "Prefs.h"
#import "../PS.h"

CFStringRef emojiFontPath2x, emojiFontPath;
CFStringRef emojiFontPath2x_o, emojiFontPath_o;
CFStringRef emojiFontFolder, newEmojiFontFolder;
CFStringRef emojiFontPathPrefix_83;

NSString *getPath(NSString *font) {
    return [NSString stringWithFormat:@"%@/%@/AppleColorEmoji@2x.ttf", (NSString *)newEmojiFontFolder, font];
}

extern "C" CFArrayRef CGFontCreateFontsWithPath(CFStringRef);
%hookf(CFArrayRef, CGFontCreateFontsWithPath, CFStringRef path) {
    if (path && ([(NSString *) path hasSuffix:@"AppleColorEmoji@2x.ttf"] || [(NSString *) path hasSuffix:@"AppleColorEmoji.ttf"])) {
        //NSString *newPath = [path stringByReplacingOccurrencesOfString:emojiFontFolder withString:newEmojiFontFolder];
        NSString *newPath = getPath(selectedFont);
        if (newPath && ![newPath isEqualToString:defaultName] && fileExist(newPath)) {
            HBLogDebug(@"New path: %@", newPath);
            return %orig((CFStringRef)newPath);
        }
    }
    return %orig(path);
}

%group iOS83Up

extern "C" CFURLRef CFURLCreateCopyAppendingPathExtension(CFAllocatorRef, CFURLRef, CFStringRef);
%hookf(CFURLRef, CFURLCreateCopyAppendingPathExtension, CFAllocatorRef allocator, CFURLRef url, CFStringRef extension) {
    if (url && CFEqual(extension, CFSTR("ccf")) && ![selectedFont isEqualToString:defaultName] && fileExist(getPath(selectedFont))) {
        CFStringRef path = CFURLCopyPath(url);
        if (CFStringHasPrefix(path, emojiFontPathPrefix_83))
            extension = CFSTR("null");
        CFRelease(path);
    }
    return %orig(allocator, url, extension);
}

%end

%ctor {
    if (isTarget(TargetTypeGUINoExtension)) {
        HaveObserver();
        callback();
        BOOL iOS82 = isiOS82;
        emojiFontPath2x = iOS82 ? CFSTR("/System/Library/Fonts/Core/AppleColorEmoji_2x.ttf") : CFSTR("/System/Library/Fonts/Core/AppleColorEmoji@2x.ttf");
        emojiFontPath = iOS82 ? CFSTR("/System/Library/Fonts/Core/AppleColorEmoji_1x.ttf") : CFSTR("/System/Library/Fonts/Core/AppleColorEmoji.ttf");
        emojiFontPath2x_o = CFSTR("/System/Library/Fonts/Cache/AppleColorEmoji@2x.ttf");
        emojiFontPath_o = CFSTR("/System/Library/Fonts/Cache/AppleColorEmoji.ttf");
        emojiFontFolder = isiOS82Up ? CFSTR("/System/Library/Fonts/Core") : CFSTR("/System/Library/Fonts/Cache");
        newEmojiFontFolder = (CFStringRef)fontsPath();
        emojiFontPathPrefix_83 = CFSTR("/System/Library/Fonts/Core/AppleColorEmoji");
        %init;
        if (isiOS83Up) {
            %init(iOS83Up);
        }
    }
}
