/*
 * IDFVSpoofer v5.1 - GGPoker Device Ban Bypass
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
#define kEnableKeychainHook @"EnableKeychainHook"
#define kEnablePopup @"EnablePopup"

static NSUUID *g_spoofedUUID = nil;
static NSString *g_spoofedString = nil;
static NSString *g_spoofedAnimationID = nil;
static NSDictionary *g_prefs = nil;

static void loadPrefs() {
    g_prefs = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
    if (!g_prefs) {
        // Default: all enabled
        g_prefs = @{
            kEnableIDFV: @YES,
            kEnableNSUserDefaults: @YES,
            kEnableKeychainClear: @YES,
            kEnableKeychainHook: @YES,
            kEnablePopup: @YES
        };
    }
}

static BOOL prefEnabled(NSString *key) {
    if (!g_prefs) loadPrefs();
    NSNumber *val = g_prefs[key];
    return val ? [val boolValue] : YES; // Default YES
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
    }
}

// ==================== HOOK UIDevice (IDFV) ====================
%hook UIDevice

- (NSUUID *)identifierForVendor {
    if (!prefEnabled(kEnableIDFV)) {
        NSLog(@"[IDFVSpoofer] IDFV hook DISABLED");
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
    if (!prefEnabled(kEnableKeychainHook)) {
        return %orig;
    }
    id orig = %orig;
    NSLog(@"[IDFVSpoofer] KeychainItemWrapper read: %@", key);
    return orig;
}

- (void)setObject:(id)inObject forKey:(id)key {
    if (!prefEnabled(kEnableKeychainHook)) {
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
        NSLog(@"[IDFVSpoofer] v5.1 Loaded in: %@", bundleID);
        NSLog(@"[IDFVSpoofer] Settings: IDFV=%d NSUserDefaults=%d KeychainClear=%d KeychainHook=%d Popup=%d",
            prefEnabled(kEnableIDFV),
            prefEnabled(kEnableNSUserDefaults),
            prefEnabled(kEnableKeychainClear),
            prefEnabled(kEnableKeychainHook),
            prefEnabled(kEnablePopup));

        initSpoofedValues();

        // Keychain clear (if enabled)
        if (prefEnabled(kEnableKeychainClear)) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                NSArray *servicesToClear = @[
                    @"appsflyer",
                    @"branch",
                    @"deviceId",
                    @"device_id",
                    @"udid",
                    @"uuid",
                    @"analytics"
                ];

                for (NSString *service in servicesToClear) {
                    NSDictionary *query = @{
                        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                        (__bridge id)kSecAttrService: service
                    };
                    SecItemDelete((__bridge CFDictionaryRef)query);
                }

                NSLog(@"[IDFVSpoofer] Keychain cleared (selective)");
            });
        }

        // Show popup (if enabled)
        if (prefEnabled(kEnablePopup)) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                NSString *status = [NSString stringWithFormat:
                    @"IDFV: %@\n\n"
                    @"Settings:\n"
                    @"• IDFV Hook: %@\n"
                    @"• NSUserDefaults: %@\n"
                    @"• Keychain Clear: %@\n"
                    @"• Keychain Hook: %@",
                    g_spoofedString,
                    prefEnabled(kEnableIDFV) ? @"ON" : @"OFF",
                    prefEnabled(kEnableNSUserDefaults) ? @"ON" : @"OFF",
                    prefEnabled(kEnableKeychainClear) ? @"ON" : @"OFF",
                    prefEnabled(kEnableKeychainHook) ? @"ON" : @"OFF"
                ];

                UIAlertController *alert = [UIAlertController
                    alertControllerWithTitle:@"IDFVSpoofer v5.1"
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
