#import <Foundation/Foundation.h>
#import <EmojiLibrary/PSEmojiUtilities.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#import <SpringBoardServices/SBSRestartRenderServerAction.h>
#import <FrontBoardServices/FBSSystemService.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#define KILL_PROCESS
#import "Prefs.h"

@interface EFMPrefController : PSListController {
    NSArray <NSString *> *allEmojiFonts;
    NSMutableDictionary <NSString *, NSString *> *fontSizes;
    NSString *selectedFont;
}
@end

@implementation EFMPrefController

- (NSMutableArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [NSMutableArray new];
        unsigned long long total = [self reloadFonts];
        NSString *groupTitle = [NSString stringWithFormat:@"Available Fonts (%@)", [NSByteCountFormatter stringFromByteCount:total countStyle:NSByteCountFormatterCountStyleBinary]];
        PSSpecifier *fontGroupSpecifier = [PSSpecifier preferenceSpecifierNamed:groupTitle target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [_specifiers addObject:fontGroupSpecifier];

        [self reloadSelectedFont];
        PSSpecifier *defaultFontSpecifier = [PSSpecifier preferenceSpecifierNamed:defaultName target:nil set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil];
        [defaultFontSpecifier setProperty:defaultName forKey:@"font"];
        [defaultFontSpecifier setProperty:@YES forKey:@"enabled"];
        [_specifiers addObject:defaultFontSpecifier];
        for (NSString *font in allEmojiFonts) {
            NSString *name = [NSString stringWithFormat:@"%@ (%@)", [font substringToIndex:font.length - 5], fontSizes[font]];
            PSSpecifier *fontSpecifier = [PSSpecifier preferenceSpecifierNamed:name target:nil set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil];
            [fontSpecifier setProperty:font forKey:@"font"];
            [fontSpecifier setProperty:@YES forKey:@"enabled"];
            [_specifiers addObject:fontSpecifier];
        }

        PSSpecifier *footerSpecifier = [PSSpecifier emptyGroupSpecifier];
        [footerSpecifier setProperty:@"\n©️ 2016 - 2025 PoomSmart" forKey:@"footerText"];
        [footerSpecifier setProperty:@1 forKey:@"footerAlignment"];
        [_specifiers addObject:footerSpecifier];

        PSSpecifier *respringSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Respring ❄️" target:nil set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        [_specifiers addObject:respringSpecifier];

        PSSpecifier *resetSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Reset emoji preferences" target:nil set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        [_specifiers addObject:resetSpecifier];
    }

    return _specifiers;
}

- (unsigned long long)reloadFonts {
    allEmojiFonts = [self allEmojiFonts];
    fontSizes = [NSMutableDictionary dictionary];
    NSFileManager *manager = [NSFileManager defaultManager];
    unsigned long long total = 0;
    for (NSString *font in allEmojiFonts) {
        NSString *path = [fontsPath stringByAppendingFormat:@"/%@/AppleColorEmoji@2x.ttc", font];
        unsigned long long fileSize = [[manager attributesOfItemAtPath:path error:nil] fileSize];
        fontSizes[font] = [NSByteCountFormatter stringFromByteCount:fileSize countStyle:NSByteCountFormatterCountStyleBinary];
        total += fileSize;
    }
    return total;
}

- (void)reloadSelectedFont {
    id value = CFBridgingRelease(CFPreferencesCopyAppValue(selectedFontKey, domain));
    selectedFont = value ? value : defaultName;
}

- (void)setSpecifier:(PSSpecifier *)specifier {
    [super setSpecifier:specifier];
    self.navigationItem.title = @"EFM 🚀";
}

- (void)respring {
    // From libcephei
    [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/FrontBoardServices.framework"] load];
    [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/SpringBoardServices.framework"] load];
    Class FBSSystemService = objc_getClass("FBSSystemService");
    if (FBSSystemService) {
        Class SBSRelaunchAction = objc_getClass("SBSRelaunchAction");
        id restartAction;
        if (SBSRelaunchAction)
            restartAction = [SBSRelaunchAction actionWithReason:@"RestartRenderServer" options:SBSRelaunchActionOptionsFadeToBlackTransition targetURL:nil];
        else
            restartAction = [objc_getClass("SBSRestartRenderServerAction") restartActionWithTargetRelaunchURL:nil];
        [[FBSSystemService sharedService] sendActions:[NSSet setWithObject:restartAction] withResult:nil];
    } else
        killProcess("SpringBoard");
}

- (NSString *)_fontsPath {
    return fontsPath;
}

- (NSArray *)allEmojiFonts {
    NSError *error = nil;
    NSArray <NSString *> *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self _fontsPath] error:&error];
    if (error)
        return @[];
    contents = [contents filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF endswith %@", @"font"]]; 
    contents = [contents sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return contents;
}

- (PSTableCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PSTableCell *tableCell = (PSTableCell *)[super tableView:tableView cellForRowAtIndexPath:indexPath];

    if (indexPath.section == 0) {
        PSSpecifier *specifier = [tableCell specifier];
        NSString *font = [specifier propertyForKey:@"font"];
        [tableCell setChecked:[selectedFont isEqualToString:font]];
    }

    return tableCell;
}

- (PSSpecifier *)specifierForFontWithName:(NSString *)fontName {
    __block PSSpecifier *specifierToReturn;
    [_specifiers enumerateObjectsUsingBlock:^(PSSpecifier* specifier, NSUInteger idx, BOOL *stop) {
        NSString *specifierFont = [specifier propertyForKey:@"font"];
        if ([fontName isEqualToString:specifierFont]) {
            specifierToReturn = specifier;
            *stop = YES;
        }
    }];
    return specifierToReturn;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
    if (indexPath.section != 0) {
        switch (indexPath.row) {
            case 0:
                [self respring];
                break;
            case 1:
                dlopen(PS_ROOT_PATH("/usr/lib/libEmojiLibrary.dylib"), RTLD_NOW);
                [objc_getClass("PSEmojiUtilities") resetEmojiPreferences];
                break;
        }
        return;
    }
    if (selectedFont) {
        PSSpecifier *previousSpecifier = [self specifierForFontWithName:selectedFont];
        NSIndexPath *previousIndexPath = [self indexPathForIndex:[self indexOfSpecifier:previousSpecifier]];
        if ([[tableView indexPathsForVisibleRows] containsObject:previousIndexPath])
            [tableView cellForRowAtIndexPath:previousIndexPath].accessoryType = UITableViewCellAccessoryNone;
    }

    PSSpecifier *specifierOfCell = [self specifierAtIndex:[self indexForIndexPath:indexPath]];
    selectedFont = [specifierOfCell propertyForKey:@"font"];
    PSTableCell *targetCell = [tableView cellForRowAtIndexPath:indexPath];
    targetCell.accessoryType = UITableViewCellAccessoryCheckmark;

    CFPreferencesSetValue(selectedFontKey, (__bridge CFStringRef)selectedFont, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFPreferencesAppSynchronize(domain);
}

@end
