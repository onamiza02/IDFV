/*
 * IDFVSpoofer - Auto Random IDFV Every App Launch
 * สำหรับ bypass device ban ใน GGPoker และแอพอื่นๆ
 */

#import <UIKit/UIKit.h>

static NSUUID *spoofedUUID = nil;
static BOOL hasShownAlert = NO;

%hook UIDevice

- (NSUUID *)identifierForVendor {
    if (spoofedUUID == nil) {
        spoofedUUID = [NSUUID UUID];
        NSLog(@"[IDFVSpoofer] New IDFV: %@", [spoofedUUID UUIDString]);

        if (!hasShownAlert) {
            hasShownAlert = YES;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                UIAlertController *alert = [UIAlertController
                    alertControllerWithTitle:@"IDFVSpoofer Active"
                    message:[NSString stringWithFormat:@"New IDFV:\n%@", [spoofedUUID UUIDString]]
                    preferredStyle:UIAlertControllerStyleAlert];

                UIAlertAction *ok = [UIAlertAction
                    actionWithTitle:@"OK"
                    style:UIAlertActionStyleDefault
                    handler:nil];
                [alert addAction:ok];

                // iOS 13+ compatible way to get key window
                UIWindow *window = nil;
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
    return spoofedUUID;
}

%end

%ctor {
    NSLog(@"[IDFVSpoofer] Loaded!");
}
