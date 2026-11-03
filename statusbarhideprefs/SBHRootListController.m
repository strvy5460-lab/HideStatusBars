#import "SBHRootListController.h"
#import "SBHAppListController.h"
#import "SBHShared.h"
#import <Preferences/PSSpecifier.h>

@implementation SBHRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // samakan file cadangan dengan nilai "enabled" yang sudah ada
    CFPropertyListRef v = CFPreferencesCopyValue(CFSTR("enabled"), (__bridge CFStringRef)kSBHDomain,
                                                 kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (v) { SBHSetPref(@"enabled", CFBridgingRelease(v)); }
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    [super setPreferenceValue:value specifier:specifier];
    NSString *key = [specifier propertyForKey:@"key"];
    if (key) SBHSetPref(key, value);
}

- (void)openApps {
    [self.navigationController pushViewController:[SBHAppListController new] animated:YES];
}

@end
