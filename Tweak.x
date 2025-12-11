/*
 * IDFVSpoofer v5.0 - GGPoker Device Ban Bypass
 * Hooks: IDFV + NSUserDefaults + Keychain
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <dlfcn.h>

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

        NSLog(@"[IDFVSpoofer] Spoofed IDFV: %@", g_spoofedString);
        NSLog(@"[IDFVSpoofer] Spoofed AnimationID: %@", g_spoofedAnimationID);
    }
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

// ==================== HOOK Keychain Wrapper Classes ====================
%hook KeychainItemWrapper

- (id)objectForKey:(id)key {
    id orig = %orig;
    NSLog(@"[IDFVSpoofer] KeychainItemWrapper read: %@", key);
    return orig;
}

- (void)setObject:(id)inObject forKey:(id)key {
    NSLog(@"[IDFVSpoofer] KeychainItemWrapper write: %@ = %@", key, inObject);
    %orig;
}

%end

// ==================== HOOK Generic Keychain Access ====================
%hook NSObject

- (id)valueForUndefinedKey:(NSString *)key {
    if ([key containsString:@"deviceId"] || [key containsString:@"DeviceId"] ||
        [key containsString:@"UUID"] || [key containsString:@"uuid"]) {
        initSpoofedValues();
        NSLog(@"[IDFVSpoofer] valueForUndefinedKey HOOKED: %@ -> %@", key, g_spoofedString);
        return g_spoofedString;
    }
    return %orig;
}

%end

// ==================== CONSTRUCTOR ====================
%ctor {
    @autoreleasepool {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (![bundleID containsString:@"nsus"]) {
            return;
        }

        NSLog(@"[IDFVSpoofer] v5.0 Loaded in: %@", bundleID);
        initSpoofedValues();

        // Clear keychain ONLY on first launch (check flag)
        NSString *flagKey = @"IDFVSpoofer_KeychainCleared";
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

        if (![defaults boolForKey:flagKey]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
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

                [defaults setBool:YES forKey:flagKey];
                [defaults synchronize];
                NSLog(@"[IDFVSpoofer] Keychain cleared (first launch only)");
            });
        } else {
            NSLog(@"[IDFVSpoofer] Keychain already cleared, skipping");
        }

        // Show popup
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:@"IDFVSpoofer v5.0"
                message:[NSString stringWithFormat:@"Device Ban Bypass Active!\n\nSpoofed IDFV:\n%@\n\nHooked:\n- IDFV\n- NSUserDefaults\n- Keychain", g_spoofedString]
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
