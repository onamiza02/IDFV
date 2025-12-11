# IDFVSpoofer

Auto randomize IDFV (identifierForVendor) on every app launch.

## Features
- Random new IDFV every time you open the app
- Bypass device bans in GGPoker, Natural8, and other apps
- Works on rootless jailbreaks (Dopamine, palera1n)
- No configuration needed - just install and forget

## Supported Apps
- GGPoker (com.nsus.ggpcom)
- Natural8 (com.nsus.natural8)

## Installation
1. Download the `.deb` file from Releases
2. Open in Sileo/Zebra or install via Filza
3. Respring
4. Done! IDFV will be randomized automatically

## How it works
The tweak hooks `UIDevice.identifierForVendor` and returns a random UUID instead of the real device identifier. This makes the app think you're using a different device every time.

## Requirements
- iOS 15.0+
- Rootless jailbreak (Dopamine, palera1n, XinaA15)
- Substrate/Substitute/ElleKit

## Build
```bash
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```
