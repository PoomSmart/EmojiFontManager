#define UIFUNCTIONS_NOT_C
#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#import <Cephei/HBRespringController.h>
#import "Prefs.h"
#import "../PSPrefs.x"
#import "../EmojiLibrary/PSEmojiUtilities.h"
#import <objc/runtime.h>
#import <dlfcn.h>

#define RowHeight 44.0

@interface EFMPrefController : PSViewController <UITableViewDataSource, UITableViewDelegate> {
    NSArray <NSString *> *allEmojiFonts;
    NSString *selectedFont;
    HBPreferences *preferences;
}
@end

@implementation EFMPrefController

- (id)init {
    if (self == [super init]) {
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Reload" style:UIBarButtonItemStylePlain target:self action:@selector(reloadTable)] autorelease];
        preferences = [[HBPreferences alloc] initWithIdentifier:tweakIdentifier];
        [self reloadFonts];
        [self reloadSelectedFont];
    }
    return self;
}

- (UITableView *)tableView {
    return (UITableView *)self.view;
}

- (UITableView *)table {
    return self.tableView;
}

- (void)loadView {
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    tableView.dataSource = self;
    tableView.delegate = self;
    tableView.rowHeight = RowHeight;
    self.view = tableView;
    [tableView release];
}

- (void)reloadFonts {
    allEmojiFonts = [[self allEmojiFonts] retain];
}

- (void)reloadSelectedFont {
    selectedFont = [[preferences objectForKey:selectedFontKey default:defaultName] retain];
}

- (void)reloadTable {
    [self reloadFonts];
    [self.tableView reloadData];
}

- (void)respring {
    [HBRespringController respring];
}

- (void)setSpecifier:(PSSpecifier *)specifier {
    [super setSpecifier:specifier];
    self.navigationItem.title = @"EFM 🚀";
    if ([self isViewLoaded]) {
        [(UITableView *)self.view setRowHeight:RowHeight];
        [(UITableView *)self.view reloadData];
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return 2;
}

- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"Available Fonts" : nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (section == [self numberOfSectionsInTableView:tableView] - 1) {
        UIView *footer2 = [[[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 320.0, 90.0)] autorelease];
        footer2.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        footer2.backgroundColor = UIColor.clearColor;
        UILabel *lbl2 = [[UILabel alloc] initWithFrame:footer2.frame];
        lbl2.backgroundColor = [UIColor clearColor];
        lbl2.text = @"©️ 2016 - 2018 Thatchapon Unprasert\n(@PoomSmart)";
        lbl2.textColor = UIColor.grayColor;
        lbl2.font = [UIFont systemFontOfSize:14.0];
        lbl2.textAlignment = NSTextAlignmentCenter;
        lbl2.lineBreakMode = NSLineBreakByWordWrapping;
        lbl2.numberOfLines = 2;
        lbl2.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [footer2 addSubview:lbl2];
        [lbl2 release];
        return footer2;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return section == [self numberOfSectionsInTableView:tableView] - 1 ? 100.0 : 0.0;
}

- (NSString *)_fontsPath {
    return fontsPath;
}

- (NSArray *)allEmojiFonts {
    NSError *error = nil;
    NSArray <NSString *> *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self _fontsPath] error:&error];
    if (error) {
        HBLogDebug(@"%@", [error localizedDescription]);
        return @[];
    }
    contents = [contents filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF endswith %@", @"font"]];
    return contents;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    if (section == 0)
        return allEmojiFonts.count + 1;
    if (section == [self numberOfSectionsInTableView:table] - 1)
        return 2 + (isiOS11Up ? 0 : 1);
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"selection"] ? : [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"selection"] autorelease];
        cell.textLabel.textAlignment = NSTextAlignmentLeft;
        cell.backgroundColor = UIColor.whiteColor;
        NSString *value = indexPath.row < allEmojiFonts.count ? allEmojiFonts[indexPath.row] : defaultName;
        cell.textLabel.text = [value stringByDeletingPathExtension];
        cell.accessoryType = [selectedFont isEqualToString:value] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        return cell;
    } else if (indexPath.section == [self numberOfSectionsInTableView:tableView] - 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"info"] ? : [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"info"] autorelease];
        cell.textLabel.text = indexPath.row == 0 ? @"Donate" : (indexPath.row == 1 ? @"Respring ❄️" : @"Reset emoji preferences");
        cell.textLabel.font = [UIFont boldSystemFontOfSize:17.0];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        return cell;
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSInteger section = indexPath.section;
    NSInteger value = indexPath.row;
    if (section == 0) {
        NSString *font = value < allEmojiFonts.count ? allEmojiFonts[value] : defaultName;
        selectedFont = font;
        for (NSInteger i = 0; i <= allEmojiFonts.count; i++) {
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:section]];
            cell.accessoryType = [[selectedFont stringByDeletingPathExtension] isEqualToString:cell.textLabel.text] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        }
        [preferences setObject:selectedFont forKey:selectedFontKey];
        DoPostNotification();
    } else if (section == 1) {
        if (value == 0)
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:PS_DONATE_URL]];
        else if (value == 1)
            [self respring];
        else
            [PSEmojiUtilities resetEmojiPreferences];
    }
}

@end
