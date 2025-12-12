/*
 * IDFVSpoofer v5.5 - GGPoker Device Ban Bypass
 * - IDFV spoof every time
 * - Keychain clear EVERY launch (not just first time)
 * - Block keychain writes via KeychainItemWrapper
 * - NSUserDefaults spoof
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>

static NSUUID *g_spoofedUUID = nil;
static NSString *g_spoofedString = nil;
static NSString *g_spoofedAnimationID = nil;

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
        NSLog(@"[IDFVSpoofer] Generated animati0nID: %@", g_spoofedAnimationID);
    }
}

static void clearKeychain() {
    NSLog(@"[IDFVSpoofer] Clearing ALL keychain items...");

    // Clear by access group
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
        NSLog(@"[IDFVSpoofer] Clear group %@: %d", group, (int)status);
    }

    // Also clear by class (catch-all)
    NSArray *secClasses = @[
        (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecClassInternetPassword
    ];

    for (id secClass in secClasses) {
        NSDictionary *query = @{(__bridge id)kSecClass: secClass};
        OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
        NSLog(@"[IDFVSpoofer] Clear class %@: %d", secClass, (int)status);
    }

    NSLog(@"[IDFVSpoofer] Keychain cleared!");
}

// ==================== HOOK UIDevice (IDFV) ====================
%hook UIDevice

- (NSUUID *)identifierForVendor {
    initSpoofedValues();
    NSLog(@"[IDFVSpoofer] IDFV HOOKED -> %@", g_spoofedString);
    return g_spoofedUUID;
}

%end

// ==================== HOOK NSUserDefaults ====================
%hook NSUserDefaults

- (id)objectForKey:(NSString *)key {
    // Spoof device-related keys
    if ([key isEqualToString:@"animati0nID"]) {
        initSpoofedValues();
        NSLog(@"[IDFVSpoofer] animati0nID HOOKED -> %@", g_spoofedAnimationID);
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
    // Block writes to device-related keys
    if ([key isEqualToString:@"animati0nID"] ||
        [key isEqualToString:@"randomSeedForValue"] ||
        [key isEqualToString:@"AppsFlyerUserId"] ||
        [key isEqualToString:@"appsflyer_user_id"]) {
        NSLog(@"[IDFVSpoofer] BLOCKED NSUserDefaults write: %@", key);
        return;
    }
    %orig;
}

%end

// ==================== HOOK KeychainItemWrapper ====================
// This hooks the Objective-C wrapper class that GGPoker might use
%hook KeychainItemWrapper

- (id)objectForKey:(id)key {
    // Return spoofed value for device ID related keys
    initSpoofedValues();
    NSLog(@"[IDFVSpoofer] KeychainItemWrapper READ blocked, returning nil for: %@", key);
    return nil;  // Return nil so app thinks keychain is empty
}

- (void)setObject:(id)inObject forKey:(id)key {
    // Block ALL writes to keychain
    NSLog(@"[IDFVSpoofer] KeychainItemWrapper WRITE blocked: %@ = %@", key, inObject);
    // Don't call %orig - block the write!
}

- (void)resetKeychainItem {
    NSLog(@"[IDFVSpoofer] KeychainItemWrapper resetKeychainItem called");
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

        NSLog(@"[IDFVSpoofer] v5.5 Loaded in: %@", bundleID);

        // Generate spoofed values first
        initSpoofedValues();

        // Clear keychain EVERY time app launches
        clearKeychain();

        // Show popup after 3 seconds
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            NSString *status = [NSString stringWithFormat:
                @"IDFV: %@\n\n"
                @"Keychain: CLEARED\n"
                @"NSUserDefaults: SPOOFED\n"
                @"KeychainWrapper: BLOCKED",
                g_spoofedString
            ];

            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:@"IDFVSpoofer v5.5"
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
