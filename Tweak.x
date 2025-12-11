/*
 * IDFVSpoofer v5.0 - GGPoker Device Ban Bypass
 * Hooks IDFV + NSUserDefaults
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

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
    }
}

// ==================== HOOK UIDevice ====================
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
        return g_spoofedAnimationID;
    }
    if ([key isEqualToString:@"randomSeedForValue"]) {
        initSpoofedValues();
        return g_spoofedString;
    }
    return %orig;
}

- (void)setObject:(id)value forKey:(NSString *)key {
    if ([key isEqualToString:@"animati0nID"] ||
        [key isEqualToString:@"randomSeedForValue"]) {
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

        NSLog(@"[IDFVSpoofer] v5.0 Loaded in: %@", bundleID);
        initSpoofedValues();

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:@"IDFVSpoofer v5.0"
                message:[NSString stringWithFormat:@"Spoofed IDFV:\n%@", g_spoofedString]
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
