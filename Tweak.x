/*
 * IDFVSpoofer v5.3 - GGPoker Device Ban Bypass
 * With Settings UI for testing each feature
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>

// Settings keys
#define PREF_PATH @"/var/mobile/Library/Preferences/com.custom.idfvspoofer.plist"
#define kEnableIDFV @"EnableIDFV"
#define kEnableNSUserDefaults @"EnableNSUserDefaults"
#define kEnableKeychainClear @"EnableKeychainClear"
#define kEnableKeychainLog @"EnableKeychainLog"
#define kEnablePopup @"EnablePopup"
#define kKeychainCleared @"KeychainCleared"

static NSUUID *g_spoofedUUID = nil;
static NSString *g_spoofedString = nil;
static NSString *g_spoofedAnimationID = nil;
static NSMutableDictionary *g_prefs = nil;

static void loadPrefs() {
    g_prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:PREF_PATH];
    if (!g_prefs) {
        g_prefs = [@{
            kEnableIDFV: @YES,
            kEnableNSUserDefaults: @YES,
            kEnableKeychainClear: @YES,
            kEnableKeychainLog: @NO,
            kEnablePopup: @YES,
            kKeychainCleared: @NO
        } mutableCopy];
    }
}

static void savePrefs() {
    [g_prefs writeToFile:PREF_PATH atomically:YES];
}

static BOOL prefEnabled(NSString *key) {
    if (!g_prefs) loadPrefs();
    NSNumber *val = g_prefs[key];
    if ([key isEqualToString:kEnableKeychainLog]) {
        return val ? [val boolValue] : NO;
    }
    return val ? [val boolValue] : YES;
}

static void initSpoofedValues() {
    if (!g_spoofedUUID) {
        g_spoofedUUID = [NSUUID UUID];
        g_spoofedString = [g_spoofedUUID UUIDString];

        NSMutableString *hexString = [NSMutableString stringWithCapacity:96];
        for (int i = 0; i < 96; i++) {
            [hexString appendFormat:@"%X", arc4random_uniform(16)];
        }
        g_spoofedAnimationID = [hexString lowercaseString];

        NSLog(@"[IDFVSpoofer] Spoofed IDFV: %@", g_spoofedString);
        NSLog(@"[IDFVSpoofer] Spoofed animati0nID: %@", g_spoofedAnimationID);
    }
}

// ==================== HOOK UIDevice (IDFV) ====================
%hook UIDevice

- (NSUUID *)identifierForVendor {
    if (!prefEnabled(kEnableIDFV)) {
        return %orig;
    }
    initSpoofedValues();
    NSLog(@"[IDFVSpoofer] IDFV HOOKED -> %@", g_spoofedString);
    return g_spoofedUUID;
}

%end

// ==================== HOOK NSUserDefaults ====================
%hook NSUserDefaults

- (id)objectForKey:(NSString *)key {
    if (!prefEnabled(kEnableNSUserDefaults)) {
        return %orig;
    }

    if ([key isEqualToString:@"animati0nID"]) {
        initSpoofedValues();
        NSLog(@"[IDFVSpoofer] animati0nID HOOKED");
        return g_spoofedAnimationID;
    }
    if ([key isEqualToString:@"randomSeedForValue"]) {
        initSpoofedValues();
        NSLog(@"[IDFVSpoofer] randomSeedForValue HOOKED -> %@", g_spoofedString);
        return g_spoofedString;
    }
    if ([key isEqualToString:@"AppsFlyerUserId"] || [key isEqualToString:@"appsflyer_user_id"]) {
        initSpoofedValues();
        NSString *fakeAF = [NSString stringWithFormat:@"%lld-%@",
            (long long)([[NSDate date] timeIntervalSince1970] * 1000),
            [g_spoofedString substringToIndex:8]];
        NSLog(@"[IDFVSpoofer] AppsFlyerUserId HOOKED -> %@", fakeAF);
        return fakeAF;
    }
    return %orig;
}

- (void)setObject:(id)value forKey:(NSString *)key {
    if (!prefEnabled(kEnableNSUserDefaults)) {
        %orig;
        return;
    }

    if ([key isEqualToString:@"animati0nID"] ||
        [key isEqualToString:@"randomSeedForValue"] ||
        [key isEqualToString:@"AppsFlyerUserId"] ||
        [key isEqualToString:@"appsflyer_user_id"]) {
        NSLog(@"[IDFVSpoofer] BLOCKED write: %@", key);
        return;
    }
    %orig;
}

%end

// ==================== HOOK Keychain Wrapper ====================
%hook KeychainItemWrapper

- (id)objectForKey:(id)key {
    if (!prefEnabled(kEnableKeychainLog)) {
        return %orig;
    }
    id orig = %orig;
    NSLog(@"[IDFVSpoofer] KeychainItemWrapper read: %@ = %@", key, orig);
    return orig;
}

- (void)setObject:(id)inObject forKey:(id)key {
    if (!prefEnabled(kEnableKeychainLog)) {
        %orig;
        return;
    }
    NSLog(@"[IDFVSpoofer] KeychainItemWrapper write: %@ = %@", key, inObject);
    %orig;
}

%end

// ==================== CONSTRUCTOR ====================
%ctor {
    @autoreleasepool {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (![bundleID containsString:@"nsus"]) {
            return;
        }

        loadPrefs();
        NSLog(@"[IDFVSpoofer] v5.3 Loaded in: %@", bundleID);
        NSLog(@"[IDFVSpoofer] Settings: IDFV=%d NSUserDefaults=%d KeychainClear=%d KeychainLog=%d Popup=%d",
            prefEnabled(kEnableIDFV),
            prefEnabled(kEnableNSUserDefaults),
            prefEnabled(kEnableKeychainClear),
            prefEnabled(kEnableKeychainLog),
            prefEnabled(kEnablePopup));

        initSpoofedValues();

        // Keychain clear - ONLY ONCE (first launch after install)
        if (prefEnabled(kEnableKeychainClear) && ![g_prefs[kKeychainCleared] boolValue]) {
            NSLog(@"[IDFVSpoofer] Clearing keychain (first time only)...");

            NSArray *accessGroups = @[
                @"XLY9G25U9L.com.nsus.ggpcom",
                @"XLY9G25U9L.com.nsus.ggpoker"
            ];

            for (NSString *group in accessGroups) {
                NSDictionary *query = @{
                    (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                    (__bridge id)kSecAttrAccessGroup: group
                };
                OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
                NSLog(@"[IDFVSpoofer] Cleared keychain %@: %d", group, (int)status);
            }

            g_prefs[kKeychainCleared] = @YES;
            savePrefs();
            NSLog(@"[IDFVSpoofer] Keychain cleared!");
        } else if (prefEnabled(kEnableKeychainClear)) {
            NSLog(@"[IDFVSpoofer] Keychain already cleared, skipping.");
        }

        // Show popup
        if (prefEnabled(kEnablePopup)) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                BOOL kcCleared = [g_prefs[kKeychainCleared] boolValue];

                NSString *status = [NSString stringWithFormat:
                    @"IDFV: %@\n\n"
                    @"Settings:\n"
                    @"- IDFV Hook: %@\n"
                    @"- NSUserDefaults: %@\n"
                    @"- Keychain Clear: %@ %@",
                    g_spoofedString,
                    prefEnabled(kEnableIDFV) ? @"ON" : @"OFF",
                    prefEnabled(kEnableNSUserDefaults) ? @"ON" : @"OFF",
                    prefEnabled(kEnableKeychainClear) ? @"ON" : @"OFF",
                    kcCleared ? @"(done)" : @"(pending)"
                ];

                UIAlertController *alert = [UIAlertController
                    alertControllerWithTitle:@"IDFVSpoofer v5.3"
                    message:status
                    preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];

                UIWindow *window = nil;
                for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                    if (scene.activationState == UISceneActivationStateForegroundActive) {
                        for (UIWindow *w in scene.windows) {
                            if (w.isKeyWindow) { window = w; break; }
                        }
                    }
                    if (window) break;
                }

                if (window) {
                    UIViewController *root = window.rootViewController;
                    while (root.presentedViewController) root = root.presentedViewController;
                    [root presentViewController:alert animated:YES completion:nil];
                }
            });
        }
    }
}
