#import "SBHRootListController.h"
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>

static NSString *const kSuite = @"com.saya.statusbarhide";
static NSString *const kNotify = @"com.saya.statusbarhide/prefschanged";

@implementation SBHRootListController

- (NSArray *)installedUserApps {
    NSMutableArray *result = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];

    Class wsClass = NSClassFromString(@"LSApplicationWorkspace");
    if (!wsClass) return result;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#pragma clang diagnostic ignored "-Wundeclared-selector"
    id ws = [wsClass performSelector:@selector(defaultWorkspace)];
    NSArray *all = [ws performSelector:@selector(allInstalledApplications)];
#pragma clang diagnostic pop

    for (id proxy in all) {
        @try {
            NSString *type = [proxy valueForKey:@"applicationType"];
            NSString *bid  = [proxy valueForKey:@"applicationIdentifier"];
            NSString *name = [proxy valueForKey:@"localizedName"];
            if (![type isEqualToString:@"User"]) continue;
            if (!bid.length || !name.length) continue;
            if ([seen containsObject:bid]) continue;
            [seen addObject:bid];
            [result addObject:@{@"bid": bid, @"name": name}];
        } @catch (NSException *e) {
            continue;
        }
    }

    [result sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] caseInsensitiveCompare:b[@"name"]];
    }];
    return result;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [[self loadSpecifiersFromPlistName:@"Root" target:self] mutableCopy];
        if (!specs) specs = [NSMutableArray array];

        PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Pilih aplikasi"];
        [group setProperty:@"Status bar hanya disembunyikan di aplikasi yang diaktifkan di sini. Tutup lalu buka lagi aplikasinya setelah mengubah pilihan."
                    forKey:@"footerText"];
        [specs addObject:group];

        for (NSDictionary *app in [self installedUserApps]) {
            PSSpecifier *s = [PSSpecifier preferenceSpecifierNamed:app[@"name"]
                                                            target:self
                                                               set:@selector(setPreferenceValue:specifier:)
                                                               get:@selector(readPreferenceValue:)
                                                            detail:nil
                                                              cell:PSSwitchCell
                                                              edit:nil];
            [s setProperty:kSuite forKey:@"defaults"];
            [s setProperty:[@"app-" stringByAppendingString:app[@"bid"]] forKey:@"key"];
            [s setProperty:@NO forKey:@"default"];
            [s setProperty:kNotify forKey:@"PostNotification"];
            [specs addObject:s];
        }

        _specifiers = [specs copy];
    }
    return _specifiers;
}

@end
