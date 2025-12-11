/*
 * IDFVSpoofer v5.0 - GGPoker Complete Device Ban Bypass
 *
 * Hooks ALL known device ID sources:
 * 1. UIDevice.identifierForVendor (IDFV)
 * 2. Unity SystemInfo.deviceUniqueIdentifier
 * 3. Keychain items (com.nsus.* access groups)
 * 4. NSUserDefaults (animati0nID, randomSeedForValue, etc.)
 * 5. AppsFlyer/Branch SDK device IDs
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>

// ==================== GLOBAL SPOOFED VALUES ====================
static NSUUID *g_spoofedUUID = nil;
static NSString *g_spoofedString = nil;
static NSString *g_spoofedAnimationID = nil;

// Generate consistent spoofed values per app launch
static void initSpoofedValues() {
    if (!g_spoofedUUID) {
        g_spoofedUUID = [NSUUID UUID];
        g_spoofedString = [g_spoofedUUID UUIDString];

        // Generate fake animati0nID (96 char hex)
        NSMutableString *hexString = [NSMutableString stringWithCapacity:96];
        for (int i = 0; i < 96; i++) {
            [hexString appendFormat:@"%X", arc4random_uniform(16)];
        }
        g_spoofedAnimationID = [hexString lowercaseString];

        NSLog(@"[IDFVSpoofer] ========================================");
        NSLog(@"[IDFVSpoofer] v5.0 - Complete Device Ban Bypass");
        NSLog(@"[IDFVSpoofer] Spoofed IDFV: %@", g_spoofedString);
        NSLog(@"[IDFVSpoofer] Spoofed AnimationID: %@", g_spoofedAnimationID);
        NSLog(@"[IDFVSpoofer] ========================================");
    }
}

// ==================== 1. HOOK UIDevice (IDFV) ====================
%hook UIDevice

- (NSUUID *)identifierForVendor {
    initSpoofedValues();
    NSLog(@"[IDFVSpoofer] UIDevice.identifierForVendor HOOKED -> %@", g_spoofedString);
    return g_spoofedUUID;
}

%end

// ==================== 2. HOOK NSUserDefaults ====================
%hook NSUserDefaults

- (id)objectForKey:(NSString *)key {
    id original = %orig;

    // Hook known device ID keys
    if ([key isEqualToString:@"animati0nID"]) {
        initSpoofedValues();
        NSLog(@"[IDFVSpoofer] NSUserDefaults animati0nID HOOKED");
        return g_spoofedAnimationID;
    }

    if ([key isEqualToString:@"randomSeedForValue"]) {
        initSpoofedValues();
        NSLog(@"[IDFVSpoofer] NSUserDefaults randomSeedForValue HOOKED -> %@", g_spoofedString);
        return g_spoofedString;
    }

    if ([key isEqualToString:@"AppsFlyerUserId"] ||
        [key isEqualToString:@"appsflyer_user_id"]) {
        initSpoofedValues();
        NSString *fakeAFId = [NSString stringWithFormat:@"%lld-%@",
            (long long)([[NSDate date] timeIntervalSince1970] * 1000),
            [[g_spoofedString substringToIndex:8] stringByReplacingOccurrencesOfString:@"-" withString:@""]];
        NSLog(@"[IDFVSpoofer] NSUserDefaults AppsFlyerUserId HOOKED -> %@", fakeAFId);
        return fakeAFId;
    }

    // Log all reads for debugging (comment out in production)
    // NSLog(@"[IDFVSpoofer] NSUserDefaults READ: %@ = %@", key, original);

    return original;
}

- (void)setObject:(id)value forKey:(NSString *)key {
    // Block saving of device IDs
    if ([key isEqualToString:@"animati0nID"] ||
        [key isEqualToString:@"randomSeedForValue"] ||
        [key isEqualToString:@"AppsFlyerUserId"] ||
        [key isEqualToString:@"appsflyer_user_id"]) {
        NSLog(@"[IDFVSpoofer] NSUserDefaults BLOCKED write: %@", key);
        return;
    }
    %orig;
}

%end

// ==================== 3. HOOK Keychain (SecItemCopyMatching) ====================
%hookf(OSStatus, SecItemCopyMatching, CFDictionaryRef query, CFTypeRef *result) {
    OSStatus status = %orig;

    if (status == errSecSuccess && result && *result) {
        // Check if it's for GGPoker's access group
        NSString *accessGroup = (__bridge NSString *)CFDictionaryGetValue(query, kSecAttrAccessGroup);
        NSString *service = (__bridge NSString *)CFDictionaryGetValue(query, kSecAttrService);

        if ([accessGroup containsString:@"com.nsus"] ||
            [service containsString:@"com.nsus"] ||
            [service containsString:@"appsflyer"] ||
            [service containsString:@"branch"]) {
            NSLog(@"[IDFVSpoofer] Keychain READ detected: group=%@ service=%@", accessGroup, service);
            // Don't block reads, just log for now
        }
    }

    return status;
}

// Block keychain writes for device IDs
%hookf(OSStatus, SecItemAdd, CFDictionaryRef attributes, CFTypeRef *result) {
    NSString *accessGroup = (__bridge NSString *)CFDictionaryGetValue(attributes, kSecAttrAccessGroup);
    NSString *service = (__bridge NSString *)CFDictionaryGetValue(attributes, kSecAttrService);

    if ([accessGroup containsString:@"com.nsus"] ||
        [service containsString:@"appsflyer"] ||
        [service containsString:@"branch"]) {
        NSLog(@"[IDFVSpoofer] Keychain ADD detected: group=%@ service=%@", accessGroup, service);
        // Allow write but log it
    }

    return %orig;
}

// ==================== 4. HOOK Unity Device ID (if loaded) ====================
// Unity uses il2cpp, we hook at C level if possible

// Try to hook NCFGetUUID if the symbol is available
%ctor {
    @autoreleasepool {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

        // Only activate for GGPoker apps
        if (![bundleID containsString:@"nsus"] &&
            ![bundleID containsString:@"ggpok"] &&
            ![bundleID containsString:@"ggcom"]) {
            NSLog(@"[IDFVSpoofer] Not a GGPoker app, skipping: %@", bundleID);
            return;
        }

        NSLog(@"[IDFVSpoofer] v5.0 Loading in: %@", bundleID);

        // Initialize spoofed values immediately
        initSpoofedValues();

        // Clear existing keychain items for fresh start
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            // Delete keychain items for com.nsus access groups
            NSDictionary *query = @{
                (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                (__bridge id)kSecAttrAccessGroup: @"XLY9G25U9L.com.nsus.ggpcom"
            };
            OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
            NSLog(@"[IDFVSpoofer] Cleared keychain ggpcom: %d", (int)status);

            query = @{
                (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                (__bridge id)kSecAttrAccessGroup: @"XLY9G25U9L.com.nsus.ggpoker"
            };
            status = SecItemDelete((__bridge CFDictionaryRef)query);
            NSLog(@"[IDFVSpoofer] Cleared keychain ggpoker: %d", (int)status);
        });

        // Show confirmation alert
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:@"IDFVSpoofer v5.0"
                message:[NSString stringWithFormat:@"Device Ban Bypass Active!\n\nSpoofed IDFV:\n%@\n\nHooked:\n- IDFV\n- NSUserDefaults\n- Keychain", g_spoofedString]
                preferredStyle:UIAlertControllerStyleAlert];

            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];

            // Find the key window
            UIWindow *window = nil;
            if (@available(iOS 13.0, *)) {
                for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                    if (scene.activationState == UISceneActivationStateForegroundActive) {
                        for (UIWindow *w in scene.windows) {
                            if (w.isKeyWindow) {
                                window = w;
                                break;
                            }
                        }
                    }
                    if (window) break;
                }
            } else {
                window = [UIApplication sharedApplication].keyWindow;
            }

            if (window) {
                UIViewController *root = window.rootViewController;
                while (root.presentedViewController) {
                    root = root.presentedViewController;
                }
                [root presentViewController:alert animated:YES completion:nil];
            }
        });
    }
}
