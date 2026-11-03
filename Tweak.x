// StatusBarHide v0.0.3
// Menyembunyikan status bar di aplikasi yang dipilih (rootless).
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define SBHLog(fmt, ...) NSLog(@"[StatusBarHide] " fmt, ##__VA_ARGS__)

static NSString *const kSBHDomain = @"com.saya.statusbarhide";
static NSString *const kSBHNotify = @"com.saya.statusbarhide/prefschanged";

static BOOL sHideThisApp = NO;
static BOOL sAppliedLegacy = NO;
static NSString *sBundleID = nil;
static NSMutableSet<NSValue *> *sHookedClasses = nil;

#pragma mark - Baca preferensi

// FIX 1: app yang di-sandbox sering TIDAK bisa membaca NSUserDefaults(suiteName:)
// milik domain lain, sehingga nilainya selalu NO -> status bar tidak pernah hilang.
// Sekarang dibaca langsung dari file plist (rootless + rootful), baru fallback ke suite.
static NSDictionary *SBHLoadPrefs(void) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray<NSString *> *paths = @[
        @"/var/jb/var/mobile/Library/Preferences/com.saya.statusbarhide.plist",
        @"/var/mobile/Library/Preferences/com.saya.statusbarhide.plist"
    ];
    NSDictionary *best = nil;
    NSDate *bestDate = nil;
    for (NSString *p in paths) {
        NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:p];
        if (!d) continue;
        NSDate *m = [fm attributesOfItemAtPath:p error:nil][NSFileModificationDate];
        if (!best) { best = d; bestDate = m; }
        else if (m && (!bestDate || [m compare:bestDate] == NSOrderedDescending)) { best = d; bestDate = m; }
    }
    if (best) return best;
    NSUserDefaults *u = [[NSUserDefaults alloc] initWithSuiteName:kSBHDomain];
    return [u dictionaryRepresentation] ?: @{};
}

static void SBHReload(void) {
    if (!sBundleID) return;
    NSDictionary *p = SBHLoadPrefs();
    BOOL enabled = [p[@"enabled"] boolValue];
    BOOL appOn = [p[[@"app-" stringByAppendingString:sBundleID]] boolValue];
    sHideThisApp = enabled && appOn;
    SBHLog(@"%@ enabled=%d app=%d -> hide=%d", sBundleID, enabled, appOn, sHideThisApp);
}

#pragma mark - FIX 2: hook subclass yang meng-override prefersStatusBarHidden

// Hook di UIViewController saja tidak cukup: banyak app punya VC sendiri yang
// meng-override prefersStatusBarHidden (return NO) sehingga hook kita dilewati.
// Di sini semua subclass yang meng-override ikut dibungkus. Hanya dijalankan
// di app yang DIPILIH.
static void SBHHookOverriders(void) {
    SEL sel = @selector(prefersStatusBarHidden);
    Class base = [UIViewController class];
    unsigned int n = 0;
    Class *list = objc_copyClassList(&n);
    for (unsigned int i = 0; i < n; i++) {
        Class c = list[i];
        if (c == base) continue;
        BOOL isVC = NO;
        for (Class s = class_getSuperclass(c); s; s = class_getSuperclass(s)) {
            if (s == base) { isVC = YES; break; }
        }
        if (!isVC) continue;

        NSValue *key = [NSValue valueWithPointer:(__bridge const void *)c];
        if ([sHookedClasses containsObject:key]) continue;

        Method m = class_getInstanceMethod(c, sel);
        Method sm = class_getInstanceMethod(class_getSuperclass(c), sel);
        if (!m || !sm) continue;
        if (method_getImplementation(m) == method_getImplementation(sm)) continue; // tidak di-override

        IMP orig = method_getImplementation(m);
        IMP repl = imp_implementationWithBlock(^BOOL(id self) {
            if (sHideThisApp) return YES;
            return ((BOOL (*)(id, SEL))orig)(self, sel);
        });
        method_setImplementation(m, repl);
        [sHookedClasses addObject:key];
    }
    if (list) free(list);
}

#pragma mark - Terapkan perubahan

static void SBHRefreshVC(UIViewController *vc, int depth) {
    if (!vc || depth > 12) return;
    [vc setNeedsStatusBarAppearanceUpdate];
    for (UIViewController *c in vc.childViewControllers) SBHRefreshVC(c, depth + 1);
    SBHRefreshVC(vc.presentedViewController, depth + 1);
}

static void SBHApply(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIApplication *app = UIApplication.sharedApplication;
        if (!app) return;

        if (sHideThisApp) SBHHookOverriders();

        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                SBHRefreshVC(w.rootViewController, 0);
            }
        }

        // FIX 3: app yang memakai UIViewControllerBasedStatusBarAppearance = NO
        // mengabaikan prefersStatusBarHidden, jadi pakai API lama juga.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if (sHideThisApp) {
            [app setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
            sAppliedLegacy = YES;
        } else if (sAppliedLegacy) {
            [app setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
            sAppliedLegacy = NO;
        }
#pragma clang diagnostic pop
    });
}

#pragma mark - Hooks

%hook UIViewController
- (BOOL)prefersStatusBarHidden { return sHideThisApp ? YES : %orig; }
- (UIViewController *)childViewControllerForStatusBarHidden { return sHideThisApp ? nil : %orig; }
%end

%hook UINavigationController
- (BOOL)prefersStatusBarHidden { return sHideThisApp ? YES : %orig; }
- (UIViewController *)childViewControllerForStatusBarHidden { return sHideThisApp ? nil : %orig; }
%end

%hook UITabBarController
- (BOOL)prefersStatusBarHidden { return sHideThisApp ? YES : %orig; }
- (UIViewController *)childViewControllerForStatusBarHidden { return sHideThisApp ? nil : %orig; }
%end

#pragma mark - Init

static void SBHPrefsChanged(CFNotificationCenterRef center, void *observer,
                            CFNotificationName name, const void *object,
                            CFDictionaryRef userInfo) {
    SBHReload();
    SBHApply();
}

%ctor {
    @autoreleasepool {
        NSBundle *main = NSBundle.mainBundle;
        NSString *bid = main.bundleIdentifier;
        if (!bid || [bid isEqualToString:@"com.apple.springboard"]) return;
        // hanya app asli (bukan extension/widget/daemon)
        if (![main.bundlePath.pathExtension isEqualToString:@"app"]) return;

        sBundleID = [bid copy];
        sHookedClasses = [NSMutableSet set];
        SBHReload();

        %init;

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL, SBHPrefsChanged,
                                        (__bridge CFStringRef)kSBHNotify, NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

        // FIX 4: muat ulang pref & terapkan tiap app tampil/aktif, karena VC belum
        // ada saat constructor jalan dan notifikasi tidak sampai ke app yang di background.
        NSArray<NSNotificationName> *names = @[
            UIApplicationDidFinishLaunchingNotification,
            UIApplicationDidBecomeActiveNotification,
            UISceneWillConnectNotification
        ];
        for (NSNotificationName n in names) {
            [NSNotificationCenter.defaultCenter addObserverForName:n object:nil
                queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
                SBHReload();
                SBHApply();
            }];
        }
    }
}
