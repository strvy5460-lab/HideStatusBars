#import <Foundation/Foundation.h>

static NSString *const kSBHDomain = @"com.saya.statusbarhide";
static NSString *const kSBHNotify = @"com.saya.statusbarhide/prefschanged";
static NSString *const kSBHMirrorPath = @"/var/jb/var/mobile/Library/Preferences/com.saya.statusbarhide.plist";

// Simpan ke cfprefsd DAN ke file plist cadangan yang bisa dibaca app (sandbox),
// lalu kirim notifikasi Darwin.
static inline void SBHSetPref(NSString *key, id value) {
    CFStringRef dom = (__bridge CFStringRef)kSBHDomain;
    CFPreferencesSetValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value,
                          dom, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFPreferencesSynchronize(dom, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);

    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithContentsOfFile:kSBHMirrorPath];
    if (!d) d = [NSMutableDictionary dictionary];
    if (value) d[key] = value; else [d removeObjectForKey:key];
    [[NSFileManager defaultManager] createDirectoryAtPath:[kSBHMirrorPath stringByDeletingLastPathComponent]
                              withIntermediateDirectories:YES attributes:nil error:nil];
    [d writeToFile:kSBHMirrorPath atomically:YES];

    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)kSBHNotify, NULL, NULL, YES);
}
