#import <Foundation/Foundation.h>
#import "IDFVRootListController.h"

@implementation IDFVRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)resetAllData {
    // Clear all saved data
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:@"_spoofed_idfv_v6"];
    [defaults removeObjectForKey:@"_idfvspoofer_keychain_cleared_v6"];
    [defaults removeObjectForKey:@"_idfvspoofer_appsflyer_reset_v6"];
    [defaults synchronize];

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Reset Complete"
        message:@"All spoofed IDs and flags have been reset. Restart GGPoker for new IDs."
        preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction
        actionWithTitle:@"OK"
        style:UIAlertActionStyleDefault
        handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)clearKeychain {
    // Clear keychain flag so it will clear again on next launch
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:@"_idfvspoofer_keychain_cleared_v6"];
    [defaults synchronize];

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Keychain Flag Reset"
        message:@"Keychain will be cleared on next GGPoker launch."
        preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction
        actionWithTitle:@"OK"
        style:UIAlertActionStyleDefault
        handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)resetAppsFlyer {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:@"_idfvspoofer_appsflyer_reset_v6"];
    [defaults synchronize];

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"AppsFlyer Flag Reset"
        message:@"AppsFlyer data will be cleared on next GGPoker launch."
        preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction
        actionWithTitle:@"OK"
        style:UIAlertActionStyleDefault
        handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

@end
