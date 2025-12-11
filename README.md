# IDFVSpoofer v5.0

Complete Device Ban Bypass for GGPoker - hooks ALL known device ID sources.

## Features
- **IDFV Spoof** - Random new identifierForVendor every launch
- **NSUserDefaults Hook** - Spoofs animati0nID, randomSeedForValue, AppsFlyerUserId
- **Keychain Clear** - Auto-clears com.nsus.* keychain items on launch
- **Keychain Logging** - Logs all keychain reads/writes for debugging
- **Visual Confirmation** - Shows alert with spoofed UUID on launch

## What Gets Hooked

| Target | Description |
|--------|-------------|
| `UIDevice.identifierForVendor` | Main IDFV - returns new UUID |
| `NSUserDefaults` read | Intercepts animati0nID, randomSeedForValue, AppsFlyerUserId |
| `NSUserDefaults` write | Blocks saving of device IDs |
| `SecItemCopyMatching` | Logs keychain reads from com.nsus.* |
| `SecItemAdd` | Logs keychain writes |
| `SecItemDelete` | Clears keychain on app launch |

## Supported Apps
- GGPoker (com.nsus.ggpcom)
- GGPOKERUK (com.nsus.ggpoker)
- Natural8 (com.nsus.natural8)

## Installation

### From Release
1. Download `.deb` from [Releases](../../releases)
2. Install via Sileo/Zebra/Filza
3. Respring
4. Open GGPoker - you'll see a popup with your new spoofed UUID

### Build from Source
```bash
# Rootful (palera1n, checkra1n)
make clean && make package FINALPACKAGE=1

# Rootless (Dopamine, palera1n rootless)
make clean && make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

## Requirements
- iOS 14.0+
- Jailbreak with Substrate/Substitute/ElleKit
- Rootful: palera1n, checkra1n (iPhone X and older)
- Rootless: Dopamine, palera1n rootless

## How It Works

GGPoker uses multiple device identifiers for ban detection:
1. **IDFV** (identifierForVendor) - Primary identifier
2. **animati0nID** - 96-char hash stored in NSUserDefaults
3. **randomSeedForValue** - UUID in NSUserDefaults
4. **Keychain items** - Shared between apps with same Team ID

This tweak intercepts ALL of these and returns spoofed values, making GGPoker think you're on a fresh device.

## Troubleshooting

**No popup appears:**
- Check if tweak is enabled in Choicy/iCleaner
- Run `ldid -s /Library/MobileSubstrate/DynamicLibraries/IDFVSpoofer.dylib`
- Check logs: `tail -f /var/log/syslog | grep IDFVSpoofer`

**Still banned:**
- Delete ALL GGPoker/Natural8 apps first
- Clear Safari data
- Respring, then reinstall GGPoker from AppStore
- The tweak will give you a fresh identity

## Changelog

### v5.0.0
- Complete rewrite with comprehensive hooks
- Added NSUserDefaults interception
- Added Keychain clearing on launch
- Added visual confirmation popup
- Switched to rootful by default

### v4.0.0
- Simple IDFV hook only

### v3.0.0
- Added Keychain clearing

### v2.0.0
- Rootless support

### v1.0.0
- Initial release
