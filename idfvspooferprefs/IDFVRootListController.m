#import <Foundation/Foundation.h>
#import "IDFVRootListController.h"

@implementation IDFVRootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}
	return _specifiers;
}

- (void)resetKeychainFlag {
	NSString *prefPath = @"/var/mobile/Library/Preferences/com.custom.idfvspoofer.plist";
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:prefPath];
	if (prefs) {
		prefs[@"KeychainCleared"] = @NO;
		[prefs writeToFile:prefPath atomically:YES];
	}

	UIAlertController *alert = [UIAlertController
		alertControllerWithTitle:@"Reset"
		message:@"Keychain will be cleared on next app launch."
		preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
	[self presentViewController:alert animated:YES completion:nil];
}

@end
