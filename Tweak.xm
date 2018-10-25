#define CHECK_TARGET
#define CHECK_EXCEPTIONS
#import "Prefs.h"
#import "../PS.h"

HBPreferences *preferences;
NSString *selectedFont;

NSString *emojiFontPath, *emojiFontPath2, *emojiFontPath3;
NSString *emojiFontFolder;

static BOOL efm_fileExist(NSString *path) {
    return fileExist(path);
}

extern "C" CFMutableArrayRef CGFontCreateFontsWithPath(CFStringRef);
%hookf(CFMutableArrayRef, CGFontCreateFontsWithPath, CFStringRef const path) {
    NSString *path_ = (__bridge NSString *)path;
    if (path && (stringEqual(path_, emojiFontPath) || stringEqual(path_, emojiFontPath2) || stringEqual(path_, emojiFontPath3))) {
        NSString *newPath = getPath(selectedFont);
        if (newPath && !stringEqual(newPath, defaultName)) {
            BOOL exist = efm_fileExist(newPath);
            if (!exist)
                exist = efm_fileExist(newPath = [newPath stringByReplacingOccurrencesOfString:@"ttf" withString:@"ttc"]);
            if (exist) {
                HBLogDebug(@"New emoji font path: %@", newPath);
                return %orig((__bridge CFStringRef const)newPath);
            }
        }
    }
    return %orig(path);
}

%group iOS83Up

extern "C" CFURLRef CFURLCreateCopyAppendingPathExtension(CFAllocatorRef, CFURLRef, CFStringRef);
%hookf(CFURLRef, CFURLCreateCopyAppendingPathExtension, CFAllocatorRef allocator, CFURLRef url, CFStringRef extension) {
    if (url && CFStringEqual(extension, CFSTR("ccf")) && !stringEqual(selectedFont, defaultName)) {
        CFStringRef path = CFURLCopyPath(url);
        if (CFStringFind(path, CFSTR("/System/Library/Fonts/Core/AppleColorEmoji"), kCFCompareCaseInsensitive).location != kCFNotFound)
            extension = CFSTR("null");
        CFRelease(path);
    }
    return %orig(allocator, url, extension);
}

%end

%ctor {
    if (_isTarget(TargetTypeGUI, @[@"com.apple.WebKit.WebContent"])) {
        preferences = [[HBPreferences alloc] initWithIdentifier:tweakIdentifier];
        [preferences registerObject:&selectedFont default:defaultName forKey:selectedFontKey];
        BOOL iOS82Up = isiOS82Up;
        emojiFontFolder = [[NSString stringWithFormat:@"/System/Library/Fonts/%@", iOS82Up ? @"Core" : @"Cache"] retain];
        emojiFontPath = [[NSString stringWithFormat:@"%@/AppleColorEmoji%@.%@", emojiFontFolder, isiOS82 ? @"_2x" : @"@2x", isiOS10Up ? @"ttc" : @"ttf"] retain];
        emojiFontPath2 = [[emojiFontPath stringByReplacingOccurrencesOfString:@"2x" withString:@"1x"] retain];
        emojiFontPath3 = [[emojiFontPath stringByReplacingOccurrencesOfString:@"1x" withString:@""] retain];
        if (isiOS83Up) {
            %init(iOS83Up);
        }
        %init;
    }
}
