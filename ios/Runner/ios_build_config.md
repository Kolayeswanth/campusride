# iOS Build Configuration for CampusRide

## Required iOS Settings

### 1. Minimum iOS Version
- Set minimum iOS version to 12.0 or higher
- Update in `ios/Runner.xcodeproj/project.pbxproj`
- Set `IPHONEOS_DEPLOYMENT_TARGET = 12.0;`

### 2. Xcode Project Settings
Open `ios/Runner.xcworkspace` in Xcode and configure:

#### Signing & Capabilities:
- Add "Background Modes" capability
- Enable "Location updates"
- Enable "Background fetch"
- Enable "Background processing"

#### Build Settings:
- Set iOS Deployment Target to 12.0+
- Enable "Always Embed Swift Standard Libraries" = YES

### 3. Required Permissions in Info.plist
Already configured:
- NSLocationWhenInUseUsageDescription
- NSLocationAlwaysAndWhenInUseUsageDescription  
- NSLocationAlwaysUsageDescription
- UIBackgroundModes

### 4. Build Commands

#### Clean Build:
```bash
cd ios
rm -rf Pods
rm Podfile.lock
cd ..
flutter clean
flutter pub get
cd ios
pod install --repo-update
cd ..
flutter build ios
```

#### Debug Build:
```bash
flutter run -d ios
```

#### Release Build:
```bash
flutter build ios --release
```

### 5. Common iOS Issues & Solutions

#### Issue: Location not working in background
**Solution**: Ensure UIBackgroundModes includes "location"

#### Issue: Permission dialog not showing
**Solution**: Check Info.plist has all required NSLocation* keys

#### Issue: App crashes on location request
**Solution**: Verify iOS deployment target is 12.0+

#### Issue: Maps not loading
**Solution**: Check NSAppTransportSecurity allows arbitrary loads

### 6. Testing on iOS Device

1. Connect iOS device via USB
2. Trust developer certificate on device
3. Run: `flutter run -d ios --release`
4. Test location permissions in Settings > Privacy & Security > Location Services

### 7. App Store Preparation

#### Required for App Store:
- Valid Apple Developer Account
- Proper code signing
- Privacy policy for location usage
- App Store Connect configuration

#### Location Usage Justification:
"This app uses location services to provide real-time bus tracking for students. Drivers share their location during active trips to help passengers track bus arrivals."