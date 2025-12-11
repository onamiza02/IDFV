/*
 * IDFVSpoofer v5.2 - GGPoker Device Ban Bypass
 * With Settings UI for testing each feature
 *
 * 2 modes for Keychain:
 * 1. Keychain Clear - ลบครั้งเดียว (อาจ crash ถ้าลบ session)
 * 2. Keychain Spoof - hook SecItemCopyMatching ให้ return ค่าปลอม (ไม่ crash, แนะนำ!)
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>

// Settings keys
#define PREF_PATH @"/var/mobile/Library/Preferences/com.custom.idfvspoofer.plist"
#define kEnableIDFV @"EnableIDFV"
#define kEnableNSUserDefaults @"EnableNSUserDefaults"
#define kEnableKeychainClear @"EnableKeychainClear"
#define kEnableKeychainSpoof @"EnableKeychainSpoof"
#define kEnableKeychainLog @"EnableKeychainLog"
#define kEnablePopup @"EnablePopup"
#define kKeychainCleared @"KeychainCleared"

static NSUUID *g_spoofedUUID = nil;
static NSString *g_spoofedString = nil;
static NSString *g_spoofedAnimationID = nil;
static NSMutableDictionary *g_prefs = nil;

// Store original SecItemCopyMatching
static OSStatus (*orig_SecItemCopyMatching)(CFDictionaryRef query, CFTypeRef *result);

static void loadPrefs() {
    g_prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:PREF_PATH];
    if (!g_prefs) {
        g_prefs = [@{
            kEnableIDFV: @YES,
            kEnableNSUserDefaults: @YES,
            kEnableKeychainClear: @NO,       // OFF by default (may crash)
            kEnableKeychainSpoof: @YES,      // ON by default (recommended!)
            kEnableKeychainLog: @NO,         // OFF by default (for debugging)
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
    // Default YES for main hooks, NO for KeychainClear
    if ([key isEqualToString:kEnableKeychainClear] || [key isEqualToString:kEnableKeychainLog]) {
        return val ? [val boolValue] : NO;
    }
    return val ? [val boolValue] : YES;
}

static void initSpoofedValues() {
    if (!g_spoofedUUID) {
        g_spoofedUUID = [NSUUID UUID];
        g_spoofedString = [g_spoofedUUID UUIDString];

        // Generate random 96-char hex for animati0nID
        NSMutableString *hexString = [NSMutableString stringWithCapacity:96];
        for (int i = 0; i < 96; i++) {
            [hexString appendFormat:@"%X", arc4random_uniform(16)];
        }
        g_spoofedAnimationID = [hexString lowercaseString];

        NSLog(@"[IDFVSpoofer] Spoofed IDFV: %@", g_spoofedString);
        NSLog(@"[IDFVSpoofer] Spoofed animati0nID: %@", g_spoofedAnimationID);
    }
}

// Check if this is a GGPoker keychain query
static BOOL isGGPokerKeychainQuery(CFDictionaryRef query) {
    NSDictionary *dict = (__bridge NSDictionary *)query;
    NSString *accessGroup = dict[(__bridge id)kSecAttrAccessGroup];
    NSString *service = dict[(__bridge id)kSecAttrService];

    // Check access group
    if (accessGroup) {
        if ([accessGroup containsString:@"com.nsus.ggp"] ||
            [accessGroup containsString:@"XLY9G25U9L"]) {
            return YES;
        }
    }

    // Check service name for known device ID patterns
    if (service) {
        if ([service containsString:@"deviceId"] ||
            [service containsString:@"device_id"] ||
            [service containsString:@"DeviceID"] ||
            [service containsString:@"udid"] ||
            [service containsString:@"UDID"]) {
            return YES;
        }
    }

    return NO;
}

// Hooked SecItemCopyMatching - spoof device ID reads
static OSStatus hook_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    if (!prefEnabled(kEnableKeychainSpoof)) {
        return orig_SecItemCopyMatching(query, result);
    }

    NSDictionary *dict = (__bridge NSDictionary *)query;
    NSString *accessGroup = dict[(__bridge id)kSecAttrAccessGroup];

    // Only intercept GGPoker keychain queries
    BOOL isGGPoker = NO;
    if (accessGroup) {
        isGGPoker = [accessGroup containsString:@"com.nsus.ggp"] ||
                    [accessGroup containsString:@"XLY9G25U9L"];
    }

    if (!isGGPoker) {
        return orig_SecItemCopyMatching(query, result);
    }

    // Call original first to see what's being read
    OSStatus status = orig_SecItemCopyMatching(query, result);

    if (prefEnabled(kEnableKeychainLog)) {
        NSLog(@"[IDFVSpoofer] SecItemCopyMatching: group=%@ status=%d", accessGroup, (int)status);
    }

    // If successful and returning data, check if it looks like a device ID
    if (status == errSecSuccess && result && *result) {
        initSpoofedValues();

        // Get the returned data
        id resultObj = (__bridge id)*result;

        if ([resultObj isKindOfClass:[NSDictionary class]]) {
            // Single item result
            NSDictionary *item = (NSDictionary *)resultObj;
            NSData *valueData = item[(__bridge id)kSecValueData];

            if (valueData) {
                NSString *valueString = [[NSString alloc] initWithData:valueData encoding:NSUTF8StringEncoding];

                // Check if this looks like a UUID/device ID (36 chars with dashes)
                if (valueString && valueString.length >= 32) {
                    // Could be UUID format or hex string - spoof it
                    if (prefEnabled(kEnableKeychainLog)) {
                        NSLog(@"[IDFVSpoofer] Spoofing keychain value: %@ -> %@",
                              [valueString substringToIndex:MIN(20, valueString.length)],
                              g_spoofedString);
                    }

                    // Create spoofed result
                    NSData *spoofedData = [g_spoofedString dataUsingEncoding:NSUTF8StringEncoding];
                    NSMutableDictionary *spoofedItem = [item mutableCopy];
                    spoofedItem[(__bridge id)kSecValueData] = spoofedData;

                    // Release original and return spoofed
                    CFRelease(*result);
                    *result = CFBridgingRetain(spoofedItem);

                    NSLog(@"[IDFVSpoofer] Keychain SPOOFED!");
                }
            }
        } else if ([resultObj isKindOfClass:[NSArray class]]) {
            // Multiple items - spoof all that look like device IDs
            NSArray *items = (NSArray *)resultObj;
            NSMutableArray *spoofedItems = [NSMutableArray arrayWithCapacity:items.count];
            BOOL didSpoof = NO;

            for (NSDictionary *item in items) {
                NSData *valueData = item[(__bridge id)kSecValueData];
                NSMutableDictionary *newItem = [item mutableCopy];

                if (valueData) {
                    NSString *valueString = [[NSString alloc] initWithData:valueData encoding:NSUTF8StringEncoding];
                    if (valueString && valueString.length >= 32) {
                        NSData *spoofedData = [g_spoofedString dataUsingEncoding:NSUTF8StringEncoding];
                        newItem[(__bridge id)kSecValueData] = spoofedData;
                        didSpoof = YES;
                    }
                }
                [spoofedItems addObject:newItem];
            }

            if (didSpoof) {
                CFRelease(*result);
                *result = CFBridgingRetain(spoofedItems);
                NSLog(@"[IDFVSpoofer] Keychain array SPOOFED!");
            }
        } else if ([resultObj isKindOfClass:[NSData class]]) {
            // Direct data result
            NSData *data = (NSData *)resultObj;
            NSString *valueString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

            if (valueString && valueString.length >= 32) {
                NSData *spoofedData = [g_spoofedString dataUsingEncoding:NSUTF8StringEncoding];
                CFRelease(*result);
                *result = CFBridgingRetain(spoofedData);
                NSLog(@"[IDFVSpoofer] Keychain data SPOOFED!");
            }
        }
    }

    return status;
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

// ==================== CONSTRUCTOR ====================
%ctor {
    @autoreleasepool {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (![bundleID containsString:@"nsus"]) {
            return;
        }

        loadPrefs();
        NSLog(@"[IDFVSpoofer] v5.2 Loaded in: %@", bundleID);
        NSLog(@"[IDFVSpoofer] Settings: IDFV=%d NSUserDefaults=%d KeychainClear=%d KeychainSpoof=%d KeychainLog=%d Popup=%d",
            prefEnabled(kEnableIDFV),
            prefEnabled(kEnableNSUserDefaults),
            prefEnabled(kEnableKeychainClear),
            prefEnabled(kEnableKeychainSpoof),
            prefEnabled(kEnableKeychainLog),
            prefEnabled(kEnablePopup));

        initSpoofedValues();

        // Hook SecItemCopyMatching using MSHookFunction (if Keychain Spoof enabled)
        if (prefEnabled(kEnableKeychainSpoof)) {
            MSHookFunction((void *)SecItemCopyMatching, (void *)hook_SecItemCopyMatching, (void **)&orig_SecItemCopyMatching);
            NSLog(@"[IDFVSpoofer] SecItemCopyMatching HOOKED!");
        }

        // Keychain clear - ONLY ONCE (first launch after install)
        if (prefEnabled(kEnableKeychainClear) && ![g_prefs[kKeychainCleared] boolValue]) {
            NSLog(@"[IDFVSpoofer] Clearing keychain (first time only)...");

            // Clear ALL items from both access groups
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

            // Mark as cleared so we don't do it again
            g_prefs[kKeychainCleared] = @YES;
            savePrefs();
            NSLog(@"[IDFVSpoofer] Keychain cleared! Won't clear again until reinstall.");
        } else if (prefEnabled(kEnableKeychainClear)) {
            NSLog(@"[IDFVSpoofer] Keychain already cleared, skipping.");
        }

        // Show popup (if enabled)
        if (prefEnabled(kEnablePopup)) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                BOOL kcCleared = [g_prefs[kKeychainCleared] boolValue];

                NSString *status = [NSString stringWithFormat:
                    @"IDFV: %@\n\n"
                    @"Settings:\n"
                    @"- IDFV Hook: %@\n"
                    @"- NSUserDefaults: %@\n"
                    @"- Keychain Spoof: %@\n"
                    @"- Keychain Clear: %@ %@",
                    g_spoofedString,
                    prefEnabled(kEnableIDFV) ? @"ON" : @"OFF",
                    prefEnabled(kEnableNSUserDefaults) ? @"ON" : @"OFF",
                    prefEnabled(kEnableKeychainSpoof) ? @"ON" : @"OFF",
                    prefEnabled(kEnableKeychainClear) ? @"ON" : @"OFF",
                    kcCleared ? @"(done)" : @"(pending)"
                ];

                UIAlertController *alert = [UIAlertController
                    alertControllerWithTitle:@"IDFVSpoofer v5.2"
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
