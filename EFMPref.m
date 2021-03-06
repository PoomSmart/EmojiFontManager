#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#import <Cephei/HBRespringController.h>
#import "Prefs.h"
#import "../EmojiLibrary/PSEmojiUtilities.h"

@interface PSTableCell (Additions)
- (void)setChecked:(BOOL)checked;
@end

@interface EFMPrefController : PSListController {
    NSArray <NSString *> *allEmojiFonts;
    NSString *selectedFont;
}
@end

@implementation EFMPrefController

- (NSMutableArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [NSMutableArray new];
        PSSpecifier *fontGroupSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Available Fonts" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [_specifiers addObject:fontGroupSpecifier];

        [self reloadFonts];
        [self reloadSelectedFont];
        PSSpecifier *defaultFontSpecifier = [PSSpecifier preferenceSpecifierNamed:defaultName target:nil set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil];
        [defaultFontSpecifier setProperty:defaultName forKey:@"font"];
        [defaultFontSpecifier setProperty:@YES forKey:@"enabled"];
        [_specifiers addObject:defaultFontSpecifier];
        for (NSString *font in allEmojiFonts) {
            PSSpecifier *fontSpecifier = [PSSpecifier preferenceSpecifierNamed:font target:nil set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil];
            [fontSpecifier setProperty:font forKey:@"font"];
            [fontSpecifier setProperty:@YES forKey:@"enabled"];
            [_specifiers addObject:fontSpecifier];
        }

        PSSpecifier *footerSpecifier = [PSSpecifier emptyGroupSpecifier];
        [footerSpecifier setProperty:@"©️ 2016 - 2021 @PoomSmart" forKey:@"footerText"];
        [footerSpecifier setProperty:@1 forKey:@"footerAlignment"];
        [_specifiers addObject:footerSpecifier];

        PSSpecifier *respringSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Respring ❄️" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        [respringSpecifier setButtonAction:@selector(respring)];
        [_specifiers addObject:respringSpecifier];

        PSSpecifier *resetSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Reset emoji preferences" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        [resetSpecifier setButtonAction:@selector(reset)];
        [_specifiers addObject:resetSpecifier];
    }

    return _specifiers;
}

- (void)reloadFonts {
    allEmojiFonts = [self allEmojiFonts];
}

- (void)reloadSelectedFont {
    id value = CFBridgingRelease(CFPreferencesCopyAppValue(selectedFontKey, domain));
    selectedFont = value ? value : defaultName;
}

- (void)setSpecifier:(PSSpecifier *)specifier {
    [super setSpecifier:specifier];
    self.navigationItem.title = @"EFM 🚀";
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
    [_specifiers enumerateObjectsUsingBlock:^(PSSpecifier* specifier, NSUInteger idx, BOOL *stop)
    {
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
    if (indexPath.section != 0) return;
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

- (void)respring {
    [HBRespringController respring];
}

- (void)reset {
    [PSEmojiUtilities resetEmojiPreferences];
}

@end
