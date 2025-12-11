/*
 * IDFVSpoofer - Auto Random IDFV Every App Launch
 * สำหรับ bypass device ban ใน GGPoker และแอพอื่นๆ
 *
 * ทำงาน: Hook UIDevice.identifierForVendor
 * ผลลัพธ์: Random UUID ใหม่ทุกครั้งที่เปิดแอพ + แจ้งเตือน
 */

#import <UIKit/UIKit.h>

// เก็บ UUID ที่ random ไว้ใช้ตลอด session
static NSUUID *spoofedUUID = nil;
static BOOL hasShownAlert = NO;

%hook UIDevice

- (NSUUID *)identifierForVendor {
    if (spoofedUUID == nil) {
        spoofedUUID = [NSUUID UUID];
        NSLog(@"[IDFVSpoofer] New IDFV: %@", [spoofedUUID UUIDString]);

        // แสดง Alert แจ้งเตือน
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

                UIWindow *window = [[UIApplication sharedApplication] keyWindow];
                UIViewController *root = window.rootViewController;
                while (root.presentedViewController) {
                    root = root.presentedViewController;
                }
                [root presentViewController:alert animated:YES completion:nil];
            });
        }
    }
    return spoofedUUID;
}

%end

%ctor {
    NSLog(@"[IDFVSpoofer] Loaded!");
}
