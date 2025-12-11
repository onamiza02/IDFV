/*
 * IDFVSpoofer v2.0 - Complete Device ID Spoofer
 * Hook ทุกที่ที่อาจเป็น Device ID:
 * 1. UIDevice.identifierForVendor (IDFV)
 * 2. Unity SystemInfo.deviceUniqueIdentifier
 * 3. ASIdentifierManager (IDFA)
 * 4. Keychain device ID
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <objc/runtime.h>

// เก็บ UUID ที่ random ไว้ใช้ตลอด session
static NSUUID *spoofedUUID = nil;
static NSString *spoofedUUIDString = nil;
static NSMutableArray *logs = nil;
static NSString *logPath = nil;

// สร้าง UUID ใหม่
static void initSpoofedUUID() {
    if (spoofedUUID == nil) {
        spoofedUUID = [NSUUID UUID];
        spoofedUUIDString = [spoofedUUID UUIDString];

        // Log
        NSString *logMsg = [NSString stringWithFormat:@"[%@] NEW UUID: %@",
            [[NSDate date] description], spoofedUUIDString];
        [logs addObject:logMsg];

        // Save log to file
        NSString *allLogs = [logs componentsJoinedByString:@"\n"];
        [allLogs writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

        NSLog(@"[IDFVSpoofer] ✅ NEW IDFV: %@", spoofedUUIDString);
    }
}

// Log function
static void addLog(NSString *msg) {
    NSString *logMsg = [NSString stringWithFormat:@"[%@] %@",
        [[NSDate date] description], msg];
    [logs addObject:logMsg];
    NSLog(@"[IDFVSpoofer] %@", msg);

    // Save to file
    NSString *allLogs = [logs componentsJoinedByString:@"\n"];
    [allLogs writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

// ==================== HOOK 1: UIDevice.identifierForVendor ====================
%hook UIDevice

- (NSUUID *)identifierForVendor {
    initSpoofedUUID();
    addLog([NSString stringWithFormat:@"HOOK UIDevice.identifierForVendor -> %@", spoofedUUIDString]);
    return spoofedUUID;
}

%end

// ==================== HOOK 2: NSUUID (เผื่อสร้างจาก string) ====================
%hook NSUUID

- (NSString *)UUIDString {
    // เช็คว่าเป็น UUID เดิมหรือเปล่า
    NSString *original = %orig;

    // ถ้าเป็น IDFV ของจริง ให้ return spoofed
    if (spoofedUUID && [self isEqual:[[UIDevice currentDevice] valueForKey:@"_identifierForVendor"]]) {
        addLog([NSString stringWithFormat:@"HOOK NSUUID.UUIDString: %@ -> %@", original, spoofedUUIDString]);
        return spoofedUUIDString;
    }

    return original;
}

%end

// ==================== HOOK 3: NSUserDefaults (เผื่อเก็บ device ID) ====================
%hook NSUserDefaults

- (id)objectForKey:(NSString *)defaultName {
    id result = %orig;

    // ถ้า key มีคำว่า device, uuid, identifier
    NSString *lowerKey = [defaultName lowercaseString];
    if ([lowerKey containsString:@"device"] ||
        [lowerKey containsString:@"uuid"] ||
        [lowerKey containsString:@"identifier"] ||
        [lowerKey containsString:@"udid"] ||
        [lowerKey containsString:@"idfv"]) {

        addLog([NSString stringWithFormat:@"HOOK NSUserDefaults.objectForKey: %@ = %@", defaultName, result]);

        // ถ้าเป็น UUID format ให้เปลี่ยน
        if ([result isKindOfClass:[NSString class]]) {
            NSString *str = (NSString *)result;
            if (str.length == 36 && [str containsString:@"-"]) {
                initSpoofedUUID();
                addLog([NSString stringWithFormat:@"  -> SPOOFED to: %@", spoofedUUIDString]);
                return spoofedUUIDString;
            }
        }
    }

    return result;
}

- (NSString *)stringForKey:(NSString *)defaultName {
    NSString *result = %orig;

    NSString *lowerKey = [defaultName lowercaseString];
    if ([lowerKey containsString:@"device"] ||
        [lowerKey containsString:@"uuid"] ||
        [lowerKey containsString:@"identifier"]) {

        addLog([NSString stringWithFormat:@"HOOK NSUserDefaults.stringForKey: %@ = %@", defaultName, result]);

        if (result.length == 36 && [result containsString:@"-"]) {
            initSpoofedUUID();
            addLog([NSString stringWithFormat:@"  -> SPOOFED to: %@", spoofedUUIDString]);
            return spoofedUUIDString;
        }
    }

    return result;
}

%end

// ==================== HOOK 4: Keychain ====================
// ลบ Keychain items ที่เก็บ device ID
static void clearDeviceIDFromKeychain() {
    NSArray *secClasses = @[
        (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecClassInternetPassword
    ];

    for (id secClass in secClasses) {
        NSDictionary *query = @{
            (__bridge id)kSecClass: secClass,
            (__bridge id)kSecReturnAttributes: @YES,
            (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll
        };

        CFTypeRef result = NULL;
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);

        if (status == errSecSuccess && result != NULL) {
            NSArray *items = (__bridge_transfer NSArray *)result;

            for (NSDictionary *item in items) {
                NSString *account = item[(__bridge id)kSecAttrAccount];
                NSString *service = item[(__bridge id)kSecAttrService];

                NSString *lowerAccount = [account lowercaseString] ?: @"";
                NSString *lowerService = [service lowercaseString] ?: @"";

                // ถ้า keychain item เกี่ยวกับ device ID
                if ([lowerAccount containsString:@"device"] ||
                    [lowerAccount containsString:@"uuid"] ||
                    [lowerAccount containsString:@"identifier"] ||
                    [lowerService containsString:@"device"] ||
                    [lowerService containsString:@"uuid"]) {

                    addLog([NSString stringWithFormat:@"KEYCHAIN FOUND: account=%@, service=%@", account, service]);

                    // ลบ item นี้
                    NSDictionary *deleteQuery = @{
                        (__bridge id)kSecClass: secClass,
                        (__bridge id)kSecAttrAccount: account ?: @"",
                        (__bridge id)kSecAttrService: service ?: @""
                    };

                    OSStatus deleteStatus = SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
                    if (deleteStatus == errSecSuccess) {
                        addLog(@"  -> DELETED from Keychain!");
                    }
                }
            }
        }
    }
}

// ==================== HOOK 5: SecItemCopyMatching (ดัก Keychain read) ====================
%hookf(OSStatus, SecItemCopyMatching, CFDictionaryRef query, CFTypeRef *result) {
    OSStatus status = %orig;

    if (status == errSecSuccess && result != NULL) {
        NSDictionary *queryDict = (__bridge NSDictionary *)query;
        NSString *account = queryDict[(__bridge id)kSecAttrAccount];
        NSString *service = queryDict[(__bridge id)kSecAttrService];

        if (account || service) {
            NSString *lowerAccount = [account lowercaseString] ?: @"";
            NSString *lowerService = [service lowercaseString] ?: @"";

            if ([lowerAccount containsString:@"device"] ||
                [lowerAccount containsString:@"uuid"] ||
                [lowerService containsString:@"device"]) {

                addLog([NSString stringWithFormat:@"HOOK SecItemCopyMatching: account=%@, service=%@", account, service]);
            }
        }
    }

    return status;
}

// ==================== CONSTRUCTOR ====================
%ctor {
    @autoreleasepool {
        // Init log array
        logs = [[NSMutableArray alloc] init];

        // Log path ใน app Documents
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDir = [paths firstObject];
        logPath = [documentsDir stringByAppendingPathComponent:@"IDFVSpoofer.log"];

        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        addLog([NSString stringWithFormat:@"========== IDFVSpoofer v2.0 LOADED =========="]);
        addLog([NSString stringWithFormat:@"App: %@", bundleID]);
        addLog([NSString stringWithFormat:@"Log: %@", logPath]);

        // Clear keychain device IDs
        clearDeviceIDFromKeychain();

        // Init spoofed UUID
        initSpoofedUUID();

        // แสดง Alert
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            NSString *msg = [NSString stringWithFormat:@"IDFV Spoofed!\n\n%@\n\nLog: %@", spoofedUUIDString, logPath];

            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:@"IDFVSpoofer v2.0"
                message:msg
                preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction *ok = [UIAlertAction
                actionWithTitle:@"OK"
                style:UIAlertActionStyleDefault
                handler:nil];

            UIAlertAction *viewLog = [UIAlertAction
                actionWithTitle:@"View Log"
                style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {
                    NSString *allLogs = [logs componentsJoinedByString:@"\n"];
                    UIAlertController *logAlert = [UIAlertController
                        alertControllerWithTitle:@"IDFVSpoofer Log"
                        message:allLogs
                        preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *close = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil];
                    [logAlert addAction:close];

                    UIWindow *window = nil;
                    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                        if (scene.activationState == UISceneActivationStateForegroundActive) {
                            for (UIWindow *w in scene.windows) {
                                if (w.isKeyWindow) { window = w; break; }
                            }
                        }
                        if (window) break;
                    }
                    UIViewController *root = window.rootViewController;
                    while (root.presentedViewController) root = root.presentedViewController;
                    [root presentViewController:logAlert animated:YES completion:nil];
                }];

            [alert addAction:ok];
            [alert addAction:viewLog];

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

        addLog(@"========== INIT COMPLETE ==========");
    }
}
