#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface IDFVSpooferPrefsController : PSListController
@end

@implementation IDFVSpooferPrefsController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

@end
