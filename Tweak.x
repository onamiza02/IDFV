/*
 * IDFVSpoofer - Auto Random IDFV Every App Launch
 * สำหรับ bypass device ban ใน GGPoker และแอพอื่นๆ
 *
 * ทำงาน: Hook UIDevice.identifierForVendor
 * ผลลัพธ์: Random UUID ใหม่ทุกครั้งที่เปิดแอพ
 */

#import <UIKit/UIKit.h>

// เก็บ UUID ที่ random ไว้ใช้ตลอด session (ไม่เปลี่ยนระหว่างใช้งาน)
static NSUUID *spoofedUUID = nil;

%hook UIDevice

- (NSUUID *)identifierForVendor {
    // สร้าง UUID ใหม่ครั้งเดียวต่อ app launch
    if (spoofedUUID == nil) {
        spoofedUUID = [NSUUID UUID];
        NSLog(@"[IDFVSpoofer] ✅ New IDFV: %@", [spoofedUUID UUIDString]);
    }
    return spoofedUUID;
}

%end

%ctor {
    NSLog(@"[IDFVSpoofer] 🚀 Loaded! IDFV will be randomized.");
}
