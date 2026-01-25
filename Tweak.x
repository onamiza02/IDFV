/*
 * IDFVSpoofer v6.0.0 - GGPoker Complete Device Ban Bypass
 *
 * Features:
 * 1. IDFV Spoofing (identifierForVendor)
 * 2. IDFA Spoofing (advertisingIdentifier)
 * 3. Unity deviceUniqueIdentifier Spoofing
 * 4. AppGuard Bypass
 * 5. Jailbreak Detection Bypass
 * 6. Anti-Hooking Detection Bypass
 * 7. Keychain Clearing
 * 8. NSUserDefaults Spoofing
 * 9. File System Check Bypass
 * 10. AppsFlyer ID Reset
 *
 * Based on research from:
 * - Shadow jailbreak bypass (github.com/jjolano/shadow)
 * - ios10_device_hook
 * - AppGuard SDK analysis
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <dlfcn.h>
#import <sys/stat.h>
#import <sys/sysctl.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>

// ==================== SETTINGS ====================
#define PREF_PATH @"/var/mobile/Library/Preferences/com.custom.idfvspoofer.plist"

static NSUUID *g_spoofedIDFV = nil;
static NSUUID *g_spoofedIDFA = nil;
static NSString *g_spoofedIDFVString = nil;
static NSString *g_spoofedIDFAString = nil;
static NSString *g_spoofedUnityID = nil;
static NSDictionary *g_settings = nil;
static BOOL g_keychainCleared = NO;

// Jailbreak paths to hide
static NSArray *g_jailbreakPaths = nil;

// Jailbreak-related URL schemes
static NSArray *g_jailbreakSchemes = nil;

// Dylibs to hide
static NSArray *g_hiddenDylibs = nil;

// ==================== INITIALIZATION ====================

static void initJailbreakPaths() {
    if (!g_jailbreakPaths) {
        g_jailbreakPaths = @[
            // Cydia & Package Managers
            @"/Applications/Cydia.app",
            @"/Applications/Sileo.app",
            @"/Applications/Zebra.app",
            @"/Applications/Installer.app",
            @"/Applications/Loader.app",

            // Substrate/Substitute/ElleKit
            @"/Library/MobileSubstrate",
            @"/Library/MobileSubstrate/MobileSubstrate.dylib",
            @"/Library/MobileSubstrate/DynamicLibraries",
            @"/usr/lib/libsubstitute.dylib",
            @"/usr/lib/substitute-loader.dylib",
            @"/usr/lib/libellekit.dylib",
            @"/usr/lib/libhooker.dylib",

            // Jailbreak files
            @"/private/var/lib/apt",
            @"/private/var/lib/cydia",
            @"/private/var/tmp/cydia.log",
            @"/private/var/stash",
            @"/private/var/mobile/Library/SBSettings/Themes",
            @"/private/var/jb",
            @"/var/jb",

            // Common jailbreak binaries
            @"/bin/bash",
            @"/bin/sh",
            @"/usr/sbin/sshd",
            @"/usr/bin/sshd",
            @"/usr/libexec/sftp-server",
            @"/etc/apt",
            @"/usr/bin/ssh",

            // System paths
            @"/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
            @"/System/Library/LaunchDaemons/com.ikey.bbot.plist",

            // Jailbreak detection files
            @"/private/var/lib/dpkg",
            @"/private/var/cache/apt",
            @"/jb",
            @"/.installed_unc0ver",
            @"/.bootstrapped_electra",

            // Rootless paths
            @"/var/jb/Library/MobileSubstrate",
            @"/var/jb/usr/lib/libsubstitute.dylib",
            @"/var/jb/usr/lib/libellekit.dylib",

            // AppGuard specific checks
            @"/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist",
            @"/Library/MobileSubstrate/DynamicLibraries/Veency.plist",
        ];
    }
}

static void initJailbreakSchemes() {
    if (!g_jailbreakSchemes) {
        g_jailbreakSchemes = @[
            @"cydia://",
            @"sileo://",
            @"zbra://",
            @"filza://",
            @"activator://",
            @"undecimus://",
            @"ssh://",
        ];
    }
}

static void initHiddenDylibs() {
    if (!g_hiddenDylibs) {
        g_hiddenDylibs = @[
            @"MobileSubstrate",
            @"substrate",
            @"substitute",
            @"ellekit",
            @"libhooker",
            @"Cydia",
            @"cycript",
            @"frida",
            @"FridaGadget",
            @"SSLKillSwitch",
            @"Shadow",
            @"Liberty",
            @"xCon",
            @"AppGuard", // Hide our own hooks from AppGuard
        ];
    }
}

static void loadSettings() {
    g_settings = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
    if (!g_settings) {
        g_settings = @{
            @"EnableIDFV": @YES,
            @"EnableIDFA": @YES,
            @"EnableNSUserDefaults": @YES,
            @"EnableKeychainClear": @YES,
            @"EnableJailbreakBypass": @YES,
            @"EnableAntiHookBypass": @YES,
            @"EnablePopup": @YES,
            @"EnableFileSystemBypass": @YES,
            @"EnableAppsFlyerReset": @YES,
        };
        [g_settings writeToFile:PREF_PATH atomically:YES];
    }
}

static BOOL isEnabled(NSString *key) {
    if (!g_settings) loadSettings();
    NSNumber *val = g_settings[key];
    return val ? [val boolValue] : YES;
}

static void initSpoofedValues() {
    if (!g_spoofedIDFV) {
        // Generate persistent spoofed IDFV
        NSString *savedIDFV = [[NSUserDefaults standardUserDefaults] stringForKey:@"_spoofed_idfv_v6"];
        if (savedIDFV) {
            g_spoofedIDFV = [[NSUUID alloc] initWithUUIDString:savedIDFV];
        }
        if (!g_spoofedIDFV) {
            g_spoofedIDFV = [NSUUID UUID];
            [[NSUserDefaults standardUserDefaults] setObject:[g_spoofedIDFV UUIDString] forKey:@"_spoofed_idfv_v6"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        g_spoofedIDFVString = [g_spoofedIDFV UUIDString];

        // Generate spoofed IDFA
        g_spoofedIDFA = [NSUUID UUID];
        g_spoofedIDFAString = [g_spoofedIDFA UUIDString];

        // Generate Unity-style device ID (same as IDFV for consistency)
        g_spoofedUnityID = g_spoofedIDFVString;

        NSLog(@"[IDFVSpoofer] === v6.0.0 Initialized ===");
        NSLog(@"[IDFVSpoofer] Spoofed IDFV: %@", g_spoofedIDFVString);
        NSLog(@"[IDFVSpoofer] Spoofed IDFA: %@", g_spoofedIDFAString);
    }
}

// ==================== KEYCHAIN CLEARING ====================

static void clearGGPokerKeychain() {
    if (g_keychainCleared) return;

    NSLog(@"[IDFVSpoofer] Clearing GGPoker keychain data...");

    // GGPoker access groups
    NSArray *accessGroups = @[
        @"XLY9G25U9L.com.nsus.ggpcom",
        @"XLY9G25U9L.com.nsus.ggpoker",
        @"XLY9G25U9L.com.nsus.natural8",
    ];

    // Clear all security classes
    NSArray *secClasses = @[
        (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecClassInternetPassword,
        (__bridge id)kSecClassCertificate,
        (__bridge id)kSecClassKey,
        (__bridge id)kSecClassIdentity,
    ];

    for (NSString *group in accessGroups) {
        for (id secClass in secClasses) {
            NSDictionary *query = @{
                (__bridge id)kSecClass: secClass,
                (__bridge id)kSecAttrAccessGroup: group,
            };
            OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
            if (status == errSecSuccess) {
                NSLog(@"[IDFVSpoofer] Cleared keychain: %@ class: %@", group, secClass);
            }
        }
    }

    // Also clear without access group (app-specific keychain)
    for (id secClass in secClasses) {
        NSDictionary *query = @{
            (__bridge id)kSecClass: secClass,
        };
        SecItemDelete((__bridge CFDictionaryRef)query);
    }

    g_keychainCleared = YES;
    NSLog(@"[IDFVSpoofer] Keychain clearing complete");
}

// ==================== APPSFLYER RESET ====================

static void resetAppsFlyerData() {
    NSLog(@"[IDFVSpoofer] Resetting AppsFlyer data...");

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *allKeys = [defaults dictionaryRepresentation];

    for (NSString *key in allKeys) {
        if ([key containsString:@"AppsFlyer"] ||
            [key containsString:@"appsflyer"] ||
            [key containsString:@"AF_"] ||
            [key containsString:@"af_"]) {
            [defaults removeObjectForKey:key];
            NSLog(@"[IDFVSpoofer] Removed AppsFlyer key: %@", key);
        }
    }

    [defaults synchronize];
}

// ==================== HELPER: CHECK JAILBREAK PATH ====================

static BOOL isJailbreakPath(NSString *path) {
    if (!path) return NO;
    initJailbreakPaths();

    for (NSString *jbPath in g_jailbreakPaths) {
        if ([path isEqualToString:jbPath] || [path hasPrefix:jbPath]) {
            return YES;
        }
    }

    // Check for common patterns
    if ([path containsString:@"Cydia"] ||
        [path containsString:@"substrate"] ||
        [path containsString:@"Substrate"] ||
        [path containsString:@"substitute"] ||
        [path containsString:@"ellekit"] ||
        [path containsString:@"libhooker"] ||
        [path containsString:@"jailbreak"] ||
        [path containsString:@"/var/jb/"] ||
        [path containsString:@"/.jb"]) {
        return YES;
    }

    return NO;
}

static BOOL isHiddenDylib(const char *path) {
    if (!path) return NO;
    initHiddenDylibs();

    NSString *pathStr = [NSString stringWithUTF8String:path];
    for (NSString *dylib in g_hiddenDylibs) {
        if ([pathStr containsString:dylib]) {
            return YES;
        }
    }
    return NO;
}

// ==================== HOOK: UIDevice (IDFV) ====================

%hook UIDevice

- (NSUUID *)identifierForVendor {
    if (!isEnabled(@"EnableIDFV")) {
        return %orig;
    }
    initSpoofedValues();
    NSLog(@"[IDFVSpoofer] IDFV hooked -> %@", g_spoofedIDFVString);
    return g_spoofedIDFV;
}

%end

// ==================== HOOK: ASIdentifierManager (IDFA) ====================

%hook ASIdentifierManager

- (NSUUID *)advertisingIdentifier {
    if (!isEnabled(@"EnableIDFA")) {
        return %orig;
    }
    initSpoofedValues();
    NSLog(@"[IDFVSpoofer] IDFA hooked -> %@", g_spoofedIDFAString);
    return g_spoofedIDFA;
}

- (BOOL)isAdvertisingTrackingEnabled {
    // Return NO to make tracking appear disabled
    return NO;
}

%end

// ==================== HOOK: NSFileManager (File System Bypass) ====================

%hook NSFileManager

- (BOOL)fileExistsAtPath:(NSString *)path {
    if (isEnabled(@"EnableFileSystemBypass") && isJailbreakPath(path)) {
        NSLog(@"[IDFVSpoofer] Blocked fileExistsAtPath: %@", path);
        return NO;
    }
    return %orig;
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory {
    if (isEnabled(@"EnableFileSystemBypass") && isJailbreakPath(path)) {
        NSLog(@"[IDFVSpoofer] Blocked fileExistsAtPath:isDirectory: %@", path);
        return NO;
    }
    return %orig;
}

- (BOOL)isReadableFileAtPath:(NSString *)path {
    if (isEnabled(@"EnableFileSystemBypass") && isJailbreakPath(path)) {
        return NO;
    }
    return %orig;
}

- (BOOL)isWritableFileAtPath:(NSString *)path {
    if (isEnabled(@"EnableFileSystemBypass") && isJailbreakPath(path)) {
        return NO;
    }
    return %orig;
}

- (BOOL)isExecutableFileAtPath:(NSString *)path {
    if (isEnabled(@"EnableFileSystemBypass") && isJailbreakPath(path)) {
        return NO;
    }
    return %orig;
}

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error {
    NSArray *contents = %orig;
    if (isEnabled(@"EnableFileSystemBypass")) {
        NSMutableArray *filtered = [NSMutableArray array];
        for (NSString *item in contents) {
            NSString *fullPath = [path stringByAppendingPathComponent:item];
            if (!isJailbreakPath(fullPath)) {
                [filtered addObject:item];
            }
        }
        return filtered;
    }
    return contents;
}

%end

// ==================== HOOK: UIApplication (URL Scheme Check) ====================

%hook UIApplication

- (BOOL)canOpenURL:(NSURL *)url {
    if (isEnabled(@"EnableJailbreakBypass")) {
        initJailbreakSchemes();
        NSString *urlString = [url absoluteString];
        for (NSString *scheme in g_jailbreakSchemes) {
            if ([urlString hasPrefix:scheme]) {
                NSLog(@"[IDFVSpoofer] Blocked canOpenURL: %@", urlString);
                return NO;
            }
        }
    }
    return %orig;
}

%end

// ==================== HOOK: NSUserDefaults ====================

%hook NSUserDefaults

- (id)objectForKey:(NSString *)key {
    if (!isEnabled(@"EnableNSUserDefaults")) {
        return %orig;
    }

    // Block AppsFlyer device ID retrieval
    if ([key containsString:@"AppsFlyerUserId"] ||
        [key containsString:@"appsflyer_user_id"]) {
        initSpoofedValues();
        NSLog(@"[IDFVSpoofer] Spoofed AppsFlyer UID request");
        return g_spoofedIDFVString;
    }

    // Block Unity device ID retrieval
    if ([key containsString:@"unity_device_id"] ||
        [key containsString:@"deviceUniqueIdentifier"]) {
        initSpoofedValues();
        NSLog(@"[IDFVSpoofer] Spoofed Unity device ID request");
        return g_spoofedUnityID;
    }

    // Block animation/tracking ID
    if ([key containsString:@"animati0nID"] ||
        [key containsString:@"gp_id"]) {
        initSpoofedValues();
        return g_spoofedIDFVString;
    }

    return %orig;
}

- (NSString *)stringForKey:(NSString *)key {
    if (!isEnabled(@"EnableNSUserDefaults")) {
        return %orig;
    }

    if ([key containsString:@"unity_device_id"] ||
        [key containsString:@"AppsFlyerUserId"] ||
        [key containsString:@"deviceUniqueIdentifier"]) {
        initSpoofedValues();
        return g_spoofedIDFVString;
    }

    return %orig;
}

%end

// ==================== HOOK: NSBundle (Detect tweaks) ====================

%hook NSBundle

- (NSString *)bundleIdentifier {
    NSString *identifier = %orig;

    // Don't let app know about substrate bundles
    if ([identifier containsString:@"substrate"] ||
        [identifier containsString:@"substitute"]) {
        return nil;
    }

    return identifier;
}

+ (NSArray *)allBundles {
    NSArray *bundles = %orig;
    if (!isEnabled(@"EnableJailbreakBypass")) {
        return bundles;
    }

    NSMutableArray *filtered = [NSMutableArray array];
    for (NSBundle *bundle in bundles) {
        NSString *path = [bundle bundlePath];
        if (!isJailbreakPath(path)) {
            [filtered addObject:bundle];
        }
    }
    return filtered;
}

%end

// ==================== HOOK: ProcessInfo (Environment) ====================

%hook NSProcessInfo

- (NSDictionary *)environment {
    NSDictionary *env = %orig;
    if (!isEnabled(@"EnableJailbreakBypass")) {
        return env;
    }

    NSMutableDictionary *filtered = [env mutableCopy];

    // Remove DYLD_INSERT_LIBRARIES which indicates injection
    [filtered removeObjectForKey:@"DYLD_INSERT_LIBRARIES"];
    [filtered removeObjectForKey:@"_MSSafeMode"];
    [filtered removeObjectForKey:@"_SafeMode"];

    return filtered;
}

%end

// ==================== C FUNCTION HOOKS ====================

// Hook stat() to hide jailbreak files
%hookf(int, stat, const char *path, struct stat *buf) {
    if (isEnabled(@"EnableFileSystemBypass") && path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if (isJailbreakPath(pathStr)) {
            NSLog(@"[IDFVSpoofer] Blocked stat(): %s", path);
            return -1;
        }
    }
    return %orig;
}

// Hook lstat() to hide jailbreak files
%hookf(int, lstat, const char *path, struct stat *buf) {
    if (isEnabled(@"EnableFileSystemBypass") && path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if (isJailbreakPath(pathStr)) {
            NSLog(@"[IDFVSpoofer] Blocked lstat(): %s", path);
            return -1;
        }
    }
    return %orig;
}

// Hook access() to hide jailbreak files
%hookf(int, access, const char *path, int mode) {
    if (isEnabled(@"EnableFileSystemBypass") && path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if (isJailbreakPath(pathStr)) {
            NSLog(@"[IDFVSpoofer] Blocked access(): %s", path);
            return -1;
        }
    }
    return %orig;
}

// Hook fopen() to block access to jailbreak files
%hookf(FILE *, fopen, const char *path, const char *mode) {
    if (isEnabled(@"EnableFileSystemBypass") && path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if (isJailbreakPath(pathStr)) {
            NSLog(@"[IDFVSpoofer] Blocked fopen(): %s", path);
            return NULL;
        }
    }
    return %orig;
}

// Hook dlopen() to prevent loading detection
%hookf(void *, dlopen, const char *path, int mode) {
    if (isEnabled(@"EnableAntiHookBypass") && path && isHiddenDylib(path)) {
        NSLog(@"[IDFVSpoofer] Blocked dlopen(): %s", path);
        return NULL;
    }
    return %orig;
}

// Hook dlsym() to hide substrate symbols
%hookf(void *, dlsym, void *handle, const char *symbol) {
    if (isEnabled(@"EnableAntiHookBypass") && symbol) {
        NSString *sym = [NSString stringWithUTF8String:symbol];
        if ([sym containsString:@"MSHookFunction"] ||
            [sym containsString:@"MSHookMessageEx"] ||
            [sym containsString:@"MSGetImageByName"] ||
            [sym containsString:@"substitute_"] ||
            [sym containsString:@"ellekit"]) {
            NSLog(@"[IDFVSpoofer] Blocked dlsym(): %s", symbol);
            return NULL;
        }
    }
    return %orig;
}

// Hook sysctl() to hide debugger attachment (anti-debugging bypass)
%hookf(int, sysctl, int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (isEnabled(@"EnableAntiHookBypass") && namelen >= 4) {
        // CTL_KERN, KERN_PROC, KERN_PROC_PID check
        if (name[0] == CTL_KERN && name[1] == KERN_PROC && name[2] == KERN_PROC_PID) {
            int ret = %orig;
            if (ret == 0 && oldp) {
                struct kinfo_proc *info = (struct kinfo_proc *)oldp;
                // Clear the P_TRACED flag (debugger attached)
                info->kp_proc.p_flag &= ~P_TRACED;
            }
            return ret;
        }
    }
    return %orig;
}

// Hook _dyld_image_count to reduce image count
%hookf(uint32_t, _dyld_image_count) {
    if (!isEnabled(@"EnableJailbreakBypass")) {
        return %orig;
    }

    uint32_t count = %orig;
    uint32_t hiddenCount = 0;

    for (uint32_t i = 0; i < count; i++) {
        const char *imageName = _dyld_get_image_name(i);
        if (imageName && isHiddenDylib(imageName)) {
            hiddenCount++;
        }
    }

    return count - hiddenCount;
}

// Hook _dyld_get_image_name to hide injected dylibs
%hookf(const char *, _dyld_get_image_name, uint32_t image_index) {
    const char *name = %orig;

    if (isEnabled(@"EnableJailbreakBypass") && name && isHiddenDylib(name)) {
        // Return empty string for hidden dylibs
        return "";
    }

    return name;
}

// ==================== APPGUARD SPECIFIC HOOKS ====================

// Try to hook AppGuard's jailbreak check directly
%ctor {
    @autoreleasepool {
        loadSettings();
        initJailbreakPaths();
        initJailbreakSchemes();
        initHiddenDylibs();

        NSLog(@"[IDFVSpoofer] === v6.0.0 Constructor ===");

        // Clear keychain on first launch if enabled
        if (isEnabled(@"EnableKeychainClear")) {
            NSString *clearedKey = @"_idfvspoofer_keychain_cleared_v6";
            if (![[NSUserDefaults standardUserDefaults] boolForKey:clearedKey]) {
                clearGGPokerKeychain();
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:clearedKey];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
        }

        // Reset AppsFlyer data if enabled
        if (isEnabled(@"EnableAppsFlyerReset")) {
            NSString *resetKey = @"_idfvspoofer_appsflyer_reset_v6";
            if (![[NSUserDefaults standardUserDefaults] boolForKey:resetKey]) {
                resetAppsFlyerData();
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:resetKey];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
        }

        // Show popup if enabled
        if (isEnabled(@"EnablePopup")) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                initSpoofedValues();

                NSString *message = [NSString stringWithFormat:
                    @"IDFVSpoofer v6.0.0 Active\n\n"
                    @"IDFV: %@\n\n"
                    @"IDFA: %@\n\n"
                    @"Jailbreak Bypass: %@\n"
                    @"Anti-Hook Bypass: %@\n"
                    @"Keychain Cleared: %@",
                    g_spoofedIDFVString,
                    g_spoofedIDFAString,
                    isEnabled(@"EnableJailbreakBypass") ? @"ON" : @"OFF",
                    isEnabled(@"EnableAntiHookBypass") ? @"ON" : @"OFF",
                    g_keychainCleared ? @"YES" : @"NO"
                ];

                UIAlertController *alert = [UIAlertController
                    alertControllerWithTitle:@"IDFVSpoofer"
                    message:message
                    preferredStyle:UIAlertControllerStyleAlert];

                [alert addAction:[UIAlertAction
                    actionWithTitle:@"OK"
                    style:UIAlertActionStyleDefault
                    handler:nil]];

                // Add reset button
                [alert addAction:[UIAlertAction
                    actionWithTitle:@"Reset All IDs"
                    style:UIAlertActionStyleDestructive
                    handler:^(UIAlertAction *action) {
                        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"_spoofed_idfv_v6"];
                        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"_idfvspoofer_keychain_cleared_v6"];
                        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"_idfvspoofer_appsflyer_reset_v6"];
                        [[NSUserDefaults standardUserDefaults] synchronize];

                        // Force regeneration
                        g_spoofedIDFV = nil;
                        g_keychainCleared = NO;

                        UIAlertController *confirm = [UIAlertController
                            alertControllerWithTitle:@"Reset Complete"
                            message:@"Please restart the app for changes to take effect."
                            preferredStyle:UIAlertControllerStyleAlert];
                        [confirm addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];

                        UIWindow *window = [[UIApplication sharedApplication] keyWindow];
                        [window.rootViewController presentViewController:confirm animated:YES completion:nil];
                    }]];

                UIWindow *window = [[UIApplication sharedApplication] keyWindow];
                if (window && window.rootViewController) {
                    [window.rootViewController presentViewController:alert animated:YES completion:nil];
                }
            });
        }

        NSLog(@"[IDFVSpoofer] Constructor complete");
    }
}
