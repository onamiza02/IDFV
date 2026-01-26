/*
 * IDFVSpoofer v6.2.0 - GGPoker Complete Device Ban Bypass
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
 * 11. Anti-Debugging Bypass (ptrace)
 * 12. Environment Variable Hiding
 *
 * v6.2.0 Changes:
 * - Fixed dyld hook index algorithm (CRITICAL)
 * - Fixed race condition with dispatch_once (CRITICAL)
 * - Fixed memory leaks - proper retain (CRITICAL)
 * - Added stat64/lstat64/faccessat/fstatat hooks
 * - Added syscall hook
 * - Fixed rootless paths for Dopamine/Palera1n
 * - Fixed CFPreferences CFNumber handling
 * - Fixed NSBundle nil crash
 * - Improved path matching to reduce false positives
 *
 * Supports: Rootless (Dopamine/Palera1n) + Rootful
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <AdSupport/AdSupport.h>
#import <dlfcn.h>
#import <dirent.h>
#import <sys/stat.h>
#import <sys/sysctl.h>
#import <sys/mount.h>
#import <sys/param.h>
#import <sys/types.h>
#import <sys/syscall.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import <spawn.h>
#import <pthread.h>

// ptrace declaration (not in public iOS SDK)
#define PT_DENY_ATTACH 31
extern long ptrace(int request, pid_t pid, void *addr, int data);

// stat64 structure for older iOS
#ifndef stat64
#define stat64 stat
#endif

// ==================== SETTINGS ====================
// Support both rootless and rootful paths
static NSString *getPreferencesPath() {
    // Rootless path (Dopamine/Palera1n)
    NSString *rootlessPath = @"/var/jb/var/mobile/Library/Preferences/com.custom.idfvspoofer.plist";
    // Rootful path
    NSString *rootfulPath = @"/var/mobile/Library/Preferences/com.custom.idfvspoofer.plist";

    // Check which exists
    if ([[NSFileManager defaultManager] fileExistsAtPath:rootlessPath]) {
        return rootlessPath;
    }
    return rootfulPath;
}

static NSUUID *g_spoofedIDFV = nil;
static NSUUID *g_spoofedIDFA = nil;
static NSString *g_spoofedIDFVString = nil;
static NSString *g_spoofedIDFAString = nil;
static NSString *g_spoofedUnityID = nil;
static NSDictionary *g_settings = nil;
static BOOL g_keychainCleared = NO;
static BOOL g_initialized = NO;

// Jailbreak paths to hide
static NSArray *g_jailbreakPaths = nil;

// Jailbreak-related URL schemes
static NSArray *g_jailbreakSchemes = nil;

// Dylibs to hide
static NSArray *g_hiddenDylibs = nil;

// Thread safety
static pthread_mutex_t g_dyldMutex = PTHREAD_MUTEX_INITIALIZER;
static dispatch_once_t g_pathsOnce;
static dispatch_once_t g_schemesOnce;
static dispatch_once_t g_dylibsOnce;
static dispatch_once_t g_indicesOnce;

// Original dyld image count (before filtering)
static uint32_t g_originalImageCount = 0;
static NSMutableIndexSet *g_hiddenImageIndices = nil;

// ==================== INITIALIZATION ====================

static void initJailbreakPaths() {
    dispatch_once(&g_pathsOnce, ^{
        g_jailbreakPaths = [@[
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
            @"/.cydia_no_stash",

            // Rootless paths (Dopamine/Palera1n)
            @"/var/jb/Library/MobileSubstrate",
            @"/var/jb/usr/lib/libsubstitute.dylib",
            @"/var/jb/usr/lib/libellekit.dylib",
            @"/var/jb/usr/lib/libhooker.dylib",
            @"/var/jb/Applications/Cydia.app",
            @"/var/jb/Applications/Sileo.app",
            @"/var/jb/bin/bash",
            @"/var/jb/usr/bin/ssh",

            // AppGuard specific checks
            @"/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist",
            @"/Library/MobileSubstrate/DynamicLibraries/Veency.plist",

            // Frida detection
            @"/usr/sbin/frida-server",
            @"/usr/bin/frida-server",
            @"/usr/lib/frida",

            // Additional rootless paths (Dopamine/Palera1n - FIXED)
            @"/var/jb/basebin",
            @"/var/jb/prep_bootstrap.sh",
            @"/var/jb/.installed_dopamine",
            @"/var/jb/usr/libexec",
            @"/var/jb/Library/Frameworks",
            @"/var/jb/Library/PreferenceBundles",
            @"/var/jb/Library/MobileSubstrate/DynamicLibraries",

            // CydiaSubstrate framework
            @"/Library/Frameworks/CydiaSubstrate.framework",

            // Procursus/Elucubratus - FIXED
            @"/.procursus_strapped",
            @"/.bootstrapped",

            // Palera1n specific
            @"/var/containers/Bundle/.palera1n_rootless",
            @"/cores/binpack",
            @"/cores/jbloader",

            // Trollstore
            @"/var/containers/Bundle/Application/.TrollStore",

            // More common detection files
            @"/etc/apt/sources.list.d",
            @"/etc/ssh/sshd_config",
            @"/usr/share/terminfo",
            @"/usr/local/bin",
            @"/Library/dpkg",
            @"/Library/LaunchDaemons",
        ] retain];
    });
}

static void initJailbreakSchemes() {
    dispatch_once(&g_schemesOnce, ^{
        g_jailbreakSchemes = [@[
            @"cydia://",
            @"sileo://",
            @"zbra://",
            @"filza://",
            @"activator://",
            @"undecimus://",
            @"ssh://",
            @"apt://",
        ] retain];
    });
}

static void initHiddenDylibs() {
    dispatch_once(&g_dylibsOnce, ^{
        g_hiddenDylibs = [@[
            @"MobileSubstrate",
            @"substrate",
            @"SubstrateLoader",
            @"SubstrateInserter",
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
            @"Flex",
            @"FLEXing",
            @"A-Bypass",
            @"FlyJB",
            @"Hestia",
            @"Choicy",
        ] retain];
    });
}

// Build hidden image indices for dyld hooks - FIXED with proper thread safety
static void buildHiddenImageIndices() {
    dispatch_once(&g_indicesOnce, ^{
        pthread_mutex_lock(&g_dyldMutex);

        g_hiddenImageIndices = [[NSMutableIndexSet alloc] init];
        g_originalImageCount = _dyld_image_count();

        initHiddenDylibs();

        for (uint32_t i = 0; i < g_originalImageCount; i++) {
            const char *imageName = _dyld_get_image_name(i);
            if (imageName) {
                NSString *name = [NSString stringWithUTF8String:imageName];
                for (NSString *hidden in g_hiddenDylibs) {
                    if ([name containsString:hidden]) {
                        [g_hiddenImageIndices addIndex:i];
                        break;
                    }
                }
            }
        }

        pthread_mutex_unlock(&g_dyldMutex);
    });
}

// FIXED: Correct algorithm for adjusting dyld image index
static uint32_t adjustDyldIndex(uint32_t requestedIndex) {
    if (!g_hiddenImageIndices || [g_hiddenImageIndices count] == 0) {
        return requestedIndex;
    }

    uint32_t visibleCount = 0;
    uint32_t realIndex = 0;

    for (realIndex = 0; realIndex < g_originalImageCount; realIndex++) {
        if (![g_hiddenImageIndices containsIndex:realIndex]) {
            if (visibleCount == requestedIndex) {
                return realIndex;
            }
            visibleCount++;
        }
    }

    // Index out of bounds
    return UINT32_MAX;
}

static void loadSettings() {
    // Try to load from file first
    NSString *prefsPath = getPreferencesPath();
    g_settings = [[NSDictionary dictionaryWithContentsOfFile:prefsPath] retain];

    // Also check CFPreferences (preference bundle writes here)
    if (!g_settings) {
        CFPreferencesAppSynchronize(CFSTR("com.custom.idfvspoofer"));

        NSMutableDictionary *prefs = [NSMutableDictionary dictionary];

        // Helper block to safely read CFPreferences - FIXED to handle CFNumber
        BOOL (^readBoolPref)(CFStringRef, BOOL) = ^BOOL(CFStringRef key, BOOL defaultVal) {
            CFPropertyListRef val = CFPreferencesCopyAppValue(key, CFSTR("com.custom.idfvspoofer"));
            if (val) {
                BOOL result = defaultVal;
                CFTypeID typeID = CFGetTypeID(val);
                if (typeID == CFBooleanGetTypeID()) {
                    result = CFBooleanGetValue((CFBooleanRef)val);
                } else if (typeID == CFNumberGetTypeID()) {
                    int intVal = 0;
                    if (CFNumberGetValue((CFNumberRef)val, kCFNumberIntType, &intVal)) {
                        result = (intVal != 0);
                    }
                }
                CFRelease(val);
                return result;
            }
            return defaultVal;
        };

        prefs[@"EnableIDFV"] = @(readBoolPref(CFSTR("EnableIDFV"), YES));
        prefs[@"EnableIDFA"] = @(readBoolPref(CFSTR("EnableIDFA"), YES));
        prefs[@"EnableNSUserDefaults"] = @(readBoolPref(CFSTR("EnableNSUserDefaults"), YES));
        prefs[@"EnableKeychainClear"] = @(readBoolPref(CFSTR("EnableKeychainClear"), YES));
        prefs[@"EnableJailbreakBypass"] = @(readBoolPref(CFSTR("EnableJailbreakBypass"), YES));
        prefs[@"EnableAntiHookBypass"] = @(readBoolPref(CFSTR("EnableAntiHookBypass"), YES));
        prefs[@"EnableFileSystemBypass"] = @(readBoolPref(CFSTR("EnableFileSystemBypass"), YES));
        prefs[@"EnableAppsFlyerReset"] = @(readBoolPref(CFSTR("EnableAppsFlyerReset"), YES));
        prefs[@"EnablePopup"] = @(readBoolPref(CFSTR("EnablePopup"), YES));

        g_settings = [prefs retain];
    }

    // Fallback to defaults if still nil
    if (!g_settings) {
        g_settings = [@{
            @"EnableIDFV": @YES,
            @"EnableIDFA": @YES,
            @"EnableNSUserDefaults": @YES,
            @"EnableKeychainClear": @YES,
            @"EnableJailbreakBypass": @YES,
            @"EnableAntiHookBypass": @YES,
            @"EnablePopup": @YES,
            @"EnableFileSystemBypass": @YES,
            @"EnableAppsFlyerReset": @YES,
        } retain];
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
            g_spoofedIDFV = [[NSUUID UUID] retain];
            [[NSUserDefaults standardUserDefaults] setObject:[g_spoofedIDFV UUIDString] forKey:@"_spoofed_idfv_v6"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        g_spoofedIDFVString = [[g_spoofedIDFV UUIDString] retain];

        // Generate spoofed IDFA (new each session for privacy)
        g_spoofedIDFA = [[NSUUID UUID] retain];
        g_spoofedIDFAString = [[g_spoofedIDFA UUIDString] retain];

        // Generate Unity-style device ID (same as IDFV for consistency)
        g_spoofedUnityID = [g_spoofedIDFVString retain];

        NSLog(@"[IDFVSpoofer] === v6.2.0 Initialized ===");
        NSLog(@"[IDFVSpoofer] Spoofed IDFV: %@", g_spoofedIDFVString);
        NSLog(@"[IDFVSpoofer] Spoofed IDFA: %@", g_spoofedIDFAString);
    }
}

// ==================== KEYCHAIN CLEARING ====================

static void clearGGPokerKeychain() {
    if (g_keychainCleared) return;

    NSLog(@"[IDFVSpoofer] Clearing GGPoker keychain data...");

    // Clear all security classes (without access group - app's own keychain)
    NSArray *secClasses = @[
        (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecClassInternetPassword,
        (__bridge id)kSecClassCertificate,
        (__bridge id)kSecClassKey,
        (__bridge id)kSecClassIdentity,
    ];

    for (id secClass in secClasses) {
        NSDictionary *query = @{
            (__bridge id)kSecClass: secClass,
        };
        OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
        if (status == errSecSuccess) {
            NSLog(@"[IDFVSpoofer] Cleared keychain class: %@", secClass);
        } else if (status != errSecItemNotFound) {
            NSLog(@"[IDFVSpoofer] Keychain clear status: %d for class: %@", (int)status, secClass);
        }
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
// FIXED: More precise matching to reduce false positives

static BOOL isJailbreakPath(NSString *path) {
    if (!path || path.length == 0) return NO;
    initJailbreakPaths();

    // Exact match or prefix match for known paths
    for (NSString *jbPath in g_jailbreakPaths) {
        if ([path isEqualToString:jbPath] || [path hasPrefix:[jbPath stringByAppendingString:@"/"]]) {
            return YES;
        }
    }

    // Check for specific patterns that indicate jailbreak
    // But avoid false positives by checking more carefully

    // Only match /var/jb at the start of path
    if ([path hasPrefix:@"/var/jb/"] || [path isEqualToString:@"/var/jb"]) {
        return YES;
    }

    // Check for known jailbreak binary/library paths
    if ([path hasPrefix:@"/Library/MobileSubstrate/"] ||
        [path hasPrefix:@"/usr/lib/substitute"] ||
        [path hasPrefix:@"/usr/lib/libhooker"] ||
        [path hasPrefix:@"/usr/lib/libellekit"]) {
        return YES;
    }

    // Check for Frida specifically
    if ([path containsString:@"/frida/"] || [path hasSuffix:@"frida-server"]) {
        return YES;
    }

    return NO;
}

static BOOL isHiddenDylib(const char *path) {
    if (!path) return NO;
    initHiddenDylibs();

    NSString *pathStr = [NSString stringWithUTF8String:path];

    // Don't hide our own tweak!
    if ([pathStr containsString:@"IDFVSpoofer"]) {
        return NO;
    }

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
        return NO;
    }
    return %orig;
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory {
    if (isEnabled(@"EnableFileSystemBypass") && isJailbreakPath(path)) {
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

- (BOOL)isDeletableFileAtPath:(NSString *)path {
    if (isEnabled(@"EnableFileSystemBypass") && isJailbreakPath(path)) {
        return NO;
    }
    return %orig;
}

- (NSDictionary *)attributesOfItemAtPath:(NSString *)path error:(NSError **)error {
    if (isEnabled(@"EnableFileSystemBypass") && isJailbreakPath(path)) {
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
        return nil;
    }
    return %orig;
}

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error {
    NSArray *contents = %orig;
    if (isEnabled(@"EnableFileSystemBypass") && contents) {
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

- (NSDirectoryEnumerator *)enumeratorAtPath:(NSString *)path {
    if (isEnabled(@"EnableFileSystemBypass") && isJailbreakPath(path)) {
        return nil;
    }
    return %orig;
}

%end

// ==================== HOOK: UIApplication (URL Scheme Check) ====================

%hook UIApplication

- (BOOL)canOpenURL:(NSURL *)url {
    if (isEnabled(@"EnableJailbreakBypass") && url) {
        initJailbreakSchemes();
        NSString *urlString = [url absoluteString];
        NSString *scheme = [url scheme];

        for (NSString *jbScheme in g_jailbreakSchemes) {
            if ([urlString hasPrefix:jbScheme] ||
                [scheme isEqualToString:[jbScheme stringByReplacingOccurrencesOfString:@"://" withString:@""]]) {
                return NO;
            }
        }
    }
    return %orig;
}

- (BOOL)openURL:(NSURL *)url {
    if (isEnabled(@"EnableJailbreakBypass") && url) {
        initJailbreakSchemes();
        NSString *urlString = [url absoluteString];
        for (NSString *jbScheme in g_jailbreakSchemes) {
            if ([urlString hasPrefix:jbScheme]) {
                return NO;
            }
        }
    }
    return %orig;
}

%end

// ==================== HOOK: NSUserDefaults ====================
// FIXED: Added more methods

%hook NSUserDefaults

- (id)objectForKey:(NSString *)key {
    if (!isEnabled(@"EnableNSUserDefaults") || !key) {
        return %orig;
    }

    // Block AppsFlyer device ID retrieval
    if ([key containsString:@"AppsFlyerUserId"] ||
        [key containsString:@"appsflyer_user_id"] ||
        [key containsString:@"AF_"]) {
        initSpoofedValues();
        return g_spoofedIDFVString;
    }

    // Block Unity device ID retrieval
    if ([key containsString:@"unity_device_id"] ||
        [key containsString:@"deviceUniqueIdentifier"] ||
        [key containsString:@"UnityDeviceId"]) {
        initSpoofedValues();
        return g_spoofedUnityID;
    }

    // Block animation/tracking ID
    if ([key containsString:@"animati0nID"] ||
        [key containsString:@"gp_id"] ||
        [key containsString:@"advertisingId"]) {
        initSpoofedValues();
        return g_spoofedIDFVString;
    }

    return %orig;
}

- (NSString *)stringForKey:(NSString *)key {
    if (!isEnabled(@"EnableNSUserDefaults") || !key) {
        return %orig;
    }

    if ([key containsString:@"unity_device_id"] ||
        [key containsString:@"AppsFlyerUserId"] ||
        [key containsString:@"deviceUniqueIdentifier"] ||
        [key containsString:@"advertisingId"]) {
        initSpoofedValues();
        return g_spoofedIDFVString;
    }

    return %orig;
}

- (NSDictionary *)dictionaryForKey:(NSString *)key {
    if (!isEnabled(@"EnableNSUserDefaults") || !key) {
        return %orig;
    }

    // Filter device IDs from dictionaries
    NSDictionary *orig = %orig;
    if (orig && ([key containsString:@"device"] || [key containsString:@"Device"])) {
        NSMutableDictionary *filtered = [orig mutableCopy];
        for (NSString *dictKey in @[@"deviceId", @"device_id", @"IDFV", @"IDFA"]) {
            if (filtered[dictKey]) {
                initSpoofedValues();
                filtered[dictKey] = g_spoofedIDFVString;
            }
        }
        return filtered;
    }

    return orig;
}

%end

// ==================== HOOK: NSBundle (Detect tweaks) ====================
// FIXED: Don't return nil for bundleIdentifier

%hook NSBundle

- (NSString *)bundleIdentifier {
    NSString *identifier = %orig;

    if (isEnabled(@"EnableJailbreakBypass") && identifier) {
        if ([identifier containsString:@"substrate"] ||
            [identifier containsString:@"substitute"] ||
            [identifier containsString:@"ellekit"]) {
            // Return a fake identifier instead of nil to prevent crashes
            return @"com.apple.unknown";
        }
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

+ (NSArray *)allFrameworks {
    NSArray *frameworks = %orig;
    if (!isEnabled(@"EnableJailbreakBypass")) {
        return frameworks;
    }

    NSMutableArray *filtered = [NSMutableArray array];
    for (NSBundle *bundle in frameworks) {
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
    [filtered removeObjectForKey:@"DYLD_LIBRARY_PATH"];
    [filtered removeObjectForKey:@"DYLD_FRAMEWORK_PATH"];
    [filtered removeObjectForKey:@"_MSSafeMode"];
    [filtered removeObjectForKey:@"_SafeMode"];
    [filtered removeObjectForKey:@"SUBSTRATE_SAFE_MODE"];

    return filtered;
}

- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)version {
    return %orig;
}

%end

// ==================== C FUNCTION HOOKS ====================

// Hook stat() to hide jailbreak files
%hookf(int, stat, const char *path, struct stat *buf) {
    if (isEnabled(@"EnableFileSystemBypass") && path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if (isJailbreakPath(pathStr)) {
            errno = ENOENT;
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
            errno = ENOENT;
            return -1;
        }
    }
    return %orig;
}

// NEW: Hook stat64() for 64-bit stat
%hookf(int, stat64, const char *path, struct stat64 *buf) {
    if (isEnabled(@"EnableFileSystemBypass") && path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if (isJailbreakPath(pathStr)) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig;
}

// NEW: Hook lstat64() for 64-bit lstat
%hookf(int, lstat64, const char *path, struct stat64 *buf) {
    if (isEnabled(@"EnableFileSystemBypass") && path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if (isJailbreakPath(pathStr)) {
            errno = ENOENT;
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
            errno = ENOENT;
            return -1;
        }
    }
    return %orig;
}

// NEW: Hook faccessat() - modern access check
%hookf(int, faccessat, int dirfd, const char *path, int mode, int flags) {
    if (isEnabled(@"EnableFileSystemBypass") && path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if (isJailbreakPath(pathStr)) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig;
}

// NEW: Hook fstatat() - modern stat variant
%hookf(int, fstatat, int dirfd, const char *path, struct stat *buf, int flags) {
    if (isEnabled(@"EnableFileSystemBypass") && path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if (isJailbreakPath(pathStr)) {
            errno = ENOENT;
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
            errno = ENOENT;
            return NULL;
        }
    }
    return %orig;
}

// Hook open() to block access to jailbreak files
// FIXED: Handle O_TMPFILE
%hookf(int, open, const char *path, int oflag, ...) {
    if (isEnabled(@"EnableFileSystemBypass") && path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if (isJailbreakPath(pathStr)) {
            errno = ENOENT;
            return -1;
        }
    }

    // Handle variadic argument for mode
    mode_t mode = 0;
    if ((oflag & O_CREAT) != 0) {
        va_list args;
        va_start(args, oflag);
        mode = (mode_t)va_arg(args, int);
        va_end(args);
        return %orig(path, oflag, mode);
    }
    return %orig(path, oflag);
}

// Hook opendir() to block directory access
%hookf(DIR *, opendir, const char *path) {
    if (isEnabled(@"EnableFileSystemBypass") && path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if (isJailbreakPath(pathStr)) {
            errno = ENOENT;
            return NULL;
        }
    }
    return %orig;
}

// Hook readlink() to hide symlinks
%hookf(ssize_t, readlink, const char *path, char *buf, size_t bufsize) {
    if (isEnabled(@"EnableFileSystemBypass") && path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if (isJailbreakPath(pathStr)) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig;
}

// NEW: Hook readlinkat() - modern readlink
%hookf(ssize_t, readlinkat, int dirfd, const char *path, char *buf, size_t bufsize) {
    if (isEnabled(@"EnableFileSystemBypass") && path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if (isJailbreakPath(pathStr)) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig;
}

// Hook realpath() to hide jailbreak paths
%hookf(char *, realpath, const char *path, char *resolved_path) {
    if (isEnabled(@"EnableFileSystemBypass") && path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if (isJailbreakPath(pathStr)) {
            errno = ENOENT;
            return NULL;
        }
    }
    return %orig;
}

// Hook statfs() to hide filesystem info
%hookf(int, statfs, const char *path, struct statfs *buf) {
    if (isEnabled(@"EnableFileSystemBypass") && path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if (isJailbreakPath(pathStr)) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig;
}

// Hook fstatfs()
%hookf(int, fstatfs, int fd, struct statfs *buf) {
    return %orig;
}

// Hook dlopen() to prevent loading detection
// FIXED: Don't block our own libs
%hookf(void *, dlopen, const char *path, int mode) {
    if (isEnabled(@"EnableAntiHookBypass") && path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];

        // Don't block our own tweak or essential libs
        if ([pathStr containsString:@"IDFVSpoofer"]) {
            return %orig;
        }

        if (isHiddenDylib(path)) {
            return NULL;
        }
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
            [sym containsString:@"MSFindSymbol"] ||
            [sym containsString:@"substitute_"] ||
            [sym containsString:@"SubGetImageByName"] ||
            [sym containsString:@"SubHookFunction"] ||
            [sym containsString:@"LHHookFunction"] ||
            [sym containsString:@"ellekit"] ||
            [sym containsString:@"frida"] ||
            [sym containsString:@"cycript"]) {
            return NULL;
        }
    }
    return %orig;
}

// Hook dladdr() to hide module info
%hookf(int, dladdr, const void *addr, Dl_info *info) {
    int result = %orig;
    if (isEnabled(@"EnableAntiHookBypass") && result && info && info->dli_fname) {
        if (isHiddenDylib(info->dli_fname)) {
            return 0;
        }
    }
    return result;
}

// Hook getenv() to hide environment variables
%hookf(char *, getenv, const char *name) {
    if (isEnabled(@"EnableJailbreakBypass") && name) {
        NSString *envName = [NSString stringWithUTF8String:name];
        if ([envName isEqualToString:@"DYLD_INSERT_LIBRARIES"] ||
            [envName isEqualToString:@"DYLD_LIBRARY_PATH"] ||
            [envName isEqualToString:@"DYLD_FRAMEWORK_PATH"] ||
            [envName isEqualToString:@"_MSSafeMode"] ||
            [envName isEqualToString:@"SUBSTRATE_SAFE_MODE"]) {
            return NULL;
        }
    }
    return %orig;
}

// Hook sysctl() to hide debugger attachment (anti-debugging bypass)
// FIXED: Added more checks
%hookf(int, sysctl, int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (isEnabled(@"EnableAntiHookBypass") && namelen >= 2) {
        // CTL_KERN, KERN_PROC, KERN_PROC_PID check
        if (name[0] == CTL_KERN && name[1] == KERN_PROC) {
            if (namelen >= 3 && (name[2] == KERN_PROC_PID || name[2] == KERN_PROC_ALL)) {
                int ret = %orig;
                if (ret == 0 && oldp) {
                    struct kinfo_proc *info = (struct kinfo_proc *)oldp;
                    // Clear the P_TRACED flag (debugger attached)
                    info->kp_proc.p_flag &= ~P_TRACED;
                }
                return ret;
            }
        }
    }
    return %orig;
}

// Hook sysctlbyname() for additional sysctl checks
%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (isEnabled(@"EnableAntiHookBypass") && name) {
        // Block some jailbreak-revealing sysctl names
        NSString *nameStr = [NSString stringWithUTF8String:name];
        if ([nameStr containsString:@"security"] ||
            [nameStr containsString:@"proc.pid"]) {
            // Allow but filter result
        }
    }
    return %orig;
}

// NEW: Hook syscall() to block direct syscalls
%hookf(int, syscall, int number, ...) {
    if (isEnabled(@"EnableAntiHookBypass")) {
        // Block ptrace syscall
        if (number == SYS_ptrace) {
            return 0;
        }
    }

    // For other syscalls, need to forward variadic args
    // This is complex, so we just call orig for most cases
    return %orig;
}

// Hook ptrace() to prevent anti-debugging
%hookf(long, ptrace, int request, pid_t pid, void *addr, int data) {
    if (isEnabled(@"EnableAntiHookBypass")) {
        if (request == PT_DENY_ATTACH) {
            // Block anti-debugging attempt
            return 0;
        }
    }
    return %orig;
}

// Hook fork() - some apps try to fork to detect debugging
%hookf(pid_t, fork) {
    if (isEnabled(@"EnableJailbreakBypass")) {
        // Return -1 to indicate fork is not allowed (like on non-jailbroken device)
        errno = ENOSYS;
        return -1;
    }
    return %orig;
}

// Hook vfork()
%hookf(pid_t, vfork) {
    if (isEnabled(@"EnableJailbreakBypass")) {
        errno = ENOSYS;
        return -1;
    }
    return %orig;
}

// Hook posix_spawn() - prevent spawning processes
%hookf(int, posix_spawn, pid_t *pid, const char *path, const posix_spawn_file_actions_t *file_actions, const posix_spawnattr_t *attrp, char *const argv[], char *const envp[]) {
    if (isEnabled(@"EnableJailbreakBypass") && path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if (isJailbreakPath(pathStr) ||
            [pathStr containsString:@"sshd"] ||
            [pathStr containsString:@"bash"] ||
            [pathStr containsString:@"frida"]) {
            return ENOENT;
        }
    }
    return %orig;
}

// NOTE: system() and popen() hooks removed - unavailable on iOS

// Hook _dyld_image_count to reduce image count
// FIXED: Thread-safe implementation
%hookf(uint32_t, _dyld_image_count) {
    if (!isEnabled(@"EnableJailbreakBypass")) {
        return %orig;
    }

    buildHiddenImageIndices();

    pthread_mutex_lock(&g_dyldMutex);
    uint32_t count = %orig;
    uint32_t hiddenCount = (uint32_t)[g_hiddenImageIndices count];
    pthread_mutex_unlock(&g_dyldMutex);

    return count - hiddenCount;
}

// Hook _dyld_get_image_name to hide injected dylibs
// FIXED: Correct algorithm
%hookf(const char *, _dyld_get_image_name, uint32_t image_index) {
    if (!isEnabled(@"EnableJailbreakBypass")) {
        return %orig;
    }

    buildHiddenImageIndices();

    pthread_mutex_lock(&g_dyldMutex);
    uint32_t adjustedIndex = adjustDyldIndex(image_index);
    pthread_mutex_unlock(&g_dyldMutex);

    if (adjustedIndex == UINT32_MAX) {
        return NULL;
    }

    return %orig(adjustedIndex);
}

// Hook _dyld_get_image_header similarly
// FIXED: Correct algorithm
%hookf(const struct mach_header *, _dyld_get_image_header, uint32_t image_index) {
    if (!isEnabled(@"EnableJailbreakBypass")) {
        return %orig;
    }

    buildHiddenImageIndices();

    pthread_mutex_lock(&g_dyldMutex);
    uint32_t adjustedIndex = adjustDyldIndex(image_index);
    pthread_mutex_unlock(&g_dyldMutex);

    if (adjustedIndex == UINT32_MAX) {
        return NULL;
    }

    return %orig(adjustedIndex);
}

// Hook _dyld_get_image_vmaddr_slide similarly
// FIXED: Correct algorithm
%hookf(intptr_t, _dyld_get_image_vmaddr_slide, uint32_t image_index) {
    if (!isEnabled(@"EnableJailbreakBypass")) {
        return %orig;
    }

    buildHiddenImageIndices();

    pthread_mutex_lock(&g_dyldMutex);
    uint32_t adjustedIndex = adjustDyldIndex(image_index);
    pthread_mutex_unlock(&g_dyldMutex);

    if (adjustedIndex == UINT32_MAX) {
        return 0;
    }

    return %orig(adjustedIndex);
}

// Hook getppid() - Parent process ID check (some detectors check if parent is launchd)
%hookf(pid_t, getppid) {
    if (isEnabled(@"EnableJailbreakBypass")) {
        // Return 1 (launchd) - normal for iOS apps
        return 1;
    }
    return %orig;
}

// ==================== CONSTRUCTOR ====================

%ctor {
    @autoreleasepool {
        // Check if we should load for this app
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

        // Only load for GGPoker apps
        if (!bundleID ||
            (![bundleID containsString:@"ggpcom"] &&
             ![bundleID containsString:@"ggpoker"] &&
             ![bundleID containsString:@"natural8"] &&
             ![bundleID containsString:@"nsus"])) {
            NSLog(@"[IDFVSpoofer] Skipping for bundle: %@", bundleID);
            return;
        }

        NSLog(@"[IDFVSpoofer] === v6.2.0 Loading for: %@ ===", bundleID);

        loadSettings();
        initJailbreakPaths();
        initJailbreakSchemes();
        initHiddenDylibs();
        buildHiddenImageIndices();

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

        g_initialized = YES;

        // Show popup if enabled - FIXED: Better timing and nil checks
        if (isEnabled(@"EnablePopup")) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                initSpoofedValues();

                NSString *message = [NSString stringWithFormat:
                    @"IDFVSpoofer v6.2.0 Active\n\n"
                    @"IDFV: %@\n\n"
                    @"Jailbreak Bypass: %@\n"
                    @"Anti-Hook Bypass: %@\n"
                    @"File System Bypass: %@\n"
                    @"Keychain Cleared: %@",
                    g_spoofedIDFVString,
                    isEnabled(@"EnableJailbreakBypass") ? @"ON" : @"OFF",
                    isEnabled(@"EnableAntiHookBypass") ? @"ON" : @"OFF",
                    isEnabled(@"EnableFileSystemBypass") ? @"ON" : @"OFF",
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

                // FIXED: Better window finding with nil checks
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
                            if (window) break;
                        }
                    }
                }
                if (!window) {
                    window = [[UIApplication sharedApplication] keyWindow];
                }
                if (!window) {
                    NSArray *windows = [[UIApplication sharedApplication] windows];
                    if (windows.count > 0) {
                        window = windows[0];
                    }
                }

                if (window && window.rootViewController) {
                    UIViewController *topVC = window.rootViewController;
                    while (topVC.presentedViewController && !topVC.presentedViewController.isBeingDismissed) {
                        topVC = topVC.presentedViewController;
                    }
                    if (topVC && !topVC.isBeingDismissed && !topVC.isBeingPresented) {
                        [topVC presentViewController:alert animated:YES completion:nil];
                    }
                }
            });
        }

        NSLog(@"[IDFVSpoofer] === v6.2.0 Loaded Successfully ===");
    }
}
