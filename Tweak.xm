#define CHECK_TARGET
#define CHECK_EXCEPTIONS
#import "Prefs.h"
#import "../PS.h"

HBPreferences *preferences;
NSString *selectedFont;

NSString *emojiFontPath1, *emojiFontPath2, *emojiFontPath3, *emojiFontPath4;
NSString *emojiFontFolder;

static NSString *getNewFontPath() {
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
    NSString *path_ = (__bridge NSString *)path;
    if (path && (stringEqual(path_, emojiFontPath1)
                || stringEqual(path_, emojiFontPath2)
                || stringEqual(path_, emojiFontPath3)
                || stringEqual(path_, emojiFontPath4)
        )) {
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
    if (CFStringEqual(name, CFSTR("AppleColorEmoji")) || CFStringEqual(name, CFSTR(".AppleColorEmojiUI"))) {
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

%ctor {
    if (_isTarget(TargetTypeApps, @[@"com.apple.WebKit.WebContent"])) {
        dlopen("/Library/Frameworks/Cephei.framework/Cephei", RTLD_NOW);
        preferences = [[NSClassFromString(@"HBPreferences") alloc] initWithIdentifier:tweakIdentifier];
        [preferences registerObject:&selectedFont default:defaultName forKey:selectedFontKey];
        BOOL iOS82Up = isiOS82Up;
        emojiFontFolder = [[NSString stringWithFormat:@"/System/Library/Fonts/%@", iOS82Up ? @"Core" : @"Cache"] retain];
        emojiFontPath1 = [[NSString stringWithFormat:@"%@/AppleColorEmoji%@.%@", emojiFontFolder, isiOS82 ? @"_2x" : @"@2x", isiOS10Up ? @"ttc" : @"ttf"] retain];
        emojiFontPath2 = [[emojiFontPath1 stringByReplacingOccurrencesOfString:@"2x" withString:@"1x"] retain];
        emojiFontPath3 = [[emojiFontPath1 stringByReplacingOccurrencesOfString:@"1x" withString:@""] retain];
        emojiFontPath4 = [[emojiFontPath1 stringByReplacingOccurrencesOfString:@"@2x" withString:@""] retain];
        MSImageRef ref = MSGetImageByName("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics");
        CGFontCreateWithPathAndName = (CGFontRef (*)(CFStringRef, CFStringRef))_PSFindSymbolCallable(ref, "_CGFontCreateWithPathAndName");
        if (CGFontCreateWithPathAndName != NULL) {
            %init(PathAndName);
        }
        if (isiOS83Up) {
            %init(iOS83Up);
        }
        %init(Path);
    }
}

%dtor {
    if (emojiFontPath1)
        [emojiFontPath1 autorelease];
    if (emojiFontPath2)
        [emojiFontPath2 autorelease];
    if (emojiFontPath3)
        [emojiFontPath3 autorelease];
    if (emojiFontPath4)
        [emojiFontPath4 autorelease];
    if (emojiFontFolder)
        [emojiFontFolder autorelease];
}