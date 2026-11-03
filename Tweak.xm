#import <UIKit/UIKit.h>

// StatusBarHide: sembunyikan status bar hanya di aplikasi yang dipilih.
// Pengaturan dibaca dari domain com.saya.statusbarhide:
//   enabled      (BOOL)  saklar utama
//   app-<bundle> (BOOL)  aplikasi yang dipilih

static NSString *const kSuite = @"com.saya.statusbarhide";
static BOOL gActive = NO;

static void reloadPrefs(void) {
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:kSuite];
    NSString *bid = [NSBundle mainBundle].bundleIdentifier;
    BOOL enabled = [d boolForKey:@"enabled"];
    BOOL selected = bid ? [d boolForKey:[@"app-" stringByAppendingString:bid]] : NO;
    gActive = enabled && selected;
}

static void refreshStatusBar(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIApplication *app = [UIApplication sharedApplication];
        if (!app) return;
        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                [w.rootViewController setNeedsStatusBarAppearanceUpdate];
            }
        }
    });
}

static void prefsChanged(CFNotificationCenterRef center, void *observer,
                         CFNotificationName name, const void *object,
                         CFDictionaryRef userInfo) {
    reloadPrefs();
    refreshStatusBar();
}

%hook UIViewController
- (BOOL)prefersStatusBarHidden {
    if (gActive) return YES;
    return %orig;
}
%end

%hook UINavigationController
- (BOOL)prefersStatusBarHidden {
    if (gActive) return YES;
    return %orig;
}
%end

%hook UITabBarController
- (BOOL)prefersStatusBarHidden {
    if (gActive) return YES;
    return %orig;
}
%end

%ctor {
    NSString *bid = [NSBundle mainBundle].bundleIdentifier;
    // Jangan aktif di home screen
    if (!bid || [bid isEqualToString:@"com.apple.springboard"]) return;

    reloadPrefs();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
        NULL, prefsChanged, CFSTR("com.saya.statusbarhide/prefschanged"),
        NULL, CFNotificationSuspensionBehaviorCoalesce);
    %init;
}
