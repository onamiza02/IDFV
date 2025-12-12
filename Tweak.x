/*
 * IDFVSpoofer v5.5.1 - GGPoker Device Ban Bypass
 * WITH SETTINGS - Toggle each feature ON/OFF via plist
 *
 * Settings file: /var/mobile/Library/Preferences/com.custom.idfvspoofer.plist
 * Edit with Filza or create with command:
 *
 * To disable a feature, set its value to NO/false in the plist
 * Default: ALL features ON
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>

// Settings
#define PREF_PATH @"/var/mobile/Library/Preferences/com.custom.idfvspoofer.plist"

static NSUUID *g_spoofedUUID = nil;
static NSString *g_spoofedString = nil;
static NSString *g_spoofedAnimationID = nil;
static NSDictionary *g_settings = nil;

// Load settings from plist
static void loadSettings() {
    g_settings = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
    if (!g_settings) {
        // Default: all ON
        g_settings = @{
            @"EnableIDFV": @YES,
            @"EnableNSUserDefaults": @YES,
            @"EnableKeychainClear": @YES,
            @"EnableKeychainBlock": @YES,
            @"EnablePopup": @YES
        };
        // Save defaults
        [g_settings writeToFile:PREF_PATH atomically:YES];
    }
}

static BOOL isEnabled(NSString *key) {
    if (!g_settings) loadSettings();
    NSNumber *val = g_settings[key];
    return val ? [val boolValue] : YES; // Default ON
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

        NSLog(@"[IDFVSpoofer] Generated IDFV: %@", g_spoofedString);
    }
}

static void clearKeychain() {
    NSLog(@"[IDFVSpoofer] Clearing keychain...");

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
        NSLog(@"[IDFVSpoofer] Clear %@: %d", group, (int)status);
    }
}

// ==================== HOOK UIDevice (IDFV) ====================
%hook UIDevice

- (NSUUID *)identifierForVendor {
    if (!isEnabled(@"EnableIDFV")) {
        NSLog(@"[IDFVSpoofer] IDFV hook DISABLED");
        return %orig;
    }
    initSpoofedValues();
    NSLog(@"[IDFVSpoofer] IDFV -> %@", g_spoofedString);
    return g_spoofedUUID;
}

%end

// ==================== HOOK NSUserDefaults ====================
%hook NSUserDefaults

- (id)objectForKey:(NSString *)key {
    if (!isEnabled(@"EnableNSUserDefaults")) {
        return %orig;
    }

    if ([key isEqualToString:@"animati0nID"]) {
        initSpoofedValues();
        NSLog(@"[IDFVSpoofer] animati0nID SPOOFED");
        return g_spoofedAnimationID;
    }
    if ([key isEqualToString:@"randomSeedForValue"]) {
        initSpoofedValues();
        NSLog(@"[IDFVSpoofer] randomSeedForValue SPOOFED");
        return g_spoofedString;
    }
    if ([key isEqualToString:@"AppsFlyerUserId"] || [key isEqualToString:@"appsflyer_user_id"]) {
        initSpoofedValues();
        NSString *fakeAF = [NSString stringWithFormat:@"%lld-%@",
            (long long)([[NSDate date] timeIntervalSince1970] * 1000),
            [g_spoofedString substringToIndex:8]];
        NSLog(@"[IDFVSpoofer] AppsFlyer SPOOFED -> %@", fakeAF);
        return fakeAF;
    }
    return %orig;
}

- (void)setObject:(id)value forKey:(NSString *)key {
    if (!isEnabled(@"EnableNSUserDefaults")) {
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

// ==================== HOOK KeychainItemWrapper ====================
%hook KeychainItemWrapper

- (id)objectForKey:(id)key {
    if (!isEnabled(@"EnableKeychainBlock")) {
        return %orig;
    }
    NSLog(@"[IDFVSpoofer] KeychainWrapper READ -> nil for: %@", key);
    return nil;
}

- (void)setObject:(id)inObject forKey:(id)key {
    if (!isEnabled(@"EnableKeychainBlock")) {
        %orig;
        return;
    }
    NSLog(@"[IDFVSpoofer] KeychainWrapper WRITE blocked: %@", key);
    // Don't call %orig
}

%end

// ==================== CONSTRUCTOR ====================
%ctor {
    @autoreleasepool {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (![bundleID containsString:@"nsus"]) {
            return;
        }

        loadSettings();
        NSLog(@"[IDFVSpoofer] v5.5.1 Loaded");
        NSLog(@"[IDFVSpoofer] IDFV=%d NSUserDefaults=%d KeychainClear=%d KeychainBlock=%d Popup=%d",
            isEnabled(@"EnableIDFV"),
            isEnabled(@"EnableNSUserDefaults"),
            isEnabled(@"EnableKeychainClear"),
            isEnabled(@"EnableKeychainBlock"),
            isEnabled(@"EnablePopup"));

        initSpoofedValues();

        // Clear keychain if enabled
        if (isEnabled(@"EnableKeychainClear")) {
            clearKeychain();
        }

        // Show popup
        if (isEnabled(@"EnablePopup")) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                NSString *status = [NSString stringWithFormat:
                    @"IDFV: %@\n\n"
                    @"Settings:\n"
                    @"• IDFV Hook: %@\n"
                    @"• NSUserDefaults: %@\n"
                    @"• Keychain Clear: %@\n"
                    @"• Keychain Block: %@\n\n"
                    @"Edit: %@",
                    g_spoofedString,
                    isEnabled(@"EnableIDFV") ? @"ON" : @"OFF",
                    isEnabled(@"EnableNSUserDefaults") ? @"ON" : @"OFF",
                    isEnabled(@"EnableKeychainClear") ? @"ON" : @"OFF",
                    isEnabled(@"EnableKeychainBlock") ? @"ON" : @"OFF",
                    PREF_PATH
                ];

                UIAlertController *alert = [UIAlertController
                    alertControllerWithTitle:@"IDFVSpoofer v5.5.1"
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
