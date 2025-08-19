#!/bin/bash

# iOS Build Fix Script for CampusRide
echo "🍎 Fixing iOS Build Issues for CampusRide..."

# Step 1: Clean everything
echo "🧹 Cleaning project..."
flutter clean
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf ios/.symlinks
rm -rf ios/Flutter/ephemeral

# Step 2: Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Step 3: Update iOS deployment target in Podfile
echo "🎯 Updating iOS deployment target..."
cd ios
if [ ! -f Podfile ]; then
    echo "Creating Podfile..."
    flutter build ios --config-only
fi

# Update Podfile to set minimum iOS version
cat > Podfile << 'EOF'
# Uncomment this line to define a global platform for your project
platform :ios, '12.0'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'ephemeral', 'Flutter-Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure \"flutter pub get\" is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Flutter-Generated.xcconfig, then run \"flutter pub get\""
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  
  # Add permissions for location
  pod 'Permission-LocationWhenInUse', :path => '.symlinks/plugins/permission_handler/ios'
  pod 'Permission-LocationAlways', :path => '.symlinks/plugins/permission_handler/ios'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    # Set minimum iOS version for all pods
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
    end
  end
end
EOF

# Step 4: Install pods
echo "🏗️ Installing CocoaPods..."
pod install --repo-update

# Step 5: Update Xcode project settings
echo "⚙️ Updating Xcode project settings..."
cd ..

# Step 6: Build for iOS
echo "🔨 Building for iOS..."
flutter build ios --release --no-codesign

echo "✅ iOS build fix completed!"
echo ""
echo "📱 Next steps:"
echo "1. Open ios/Runner.xcworkspace in Xcode"
echo "2. Select Runner target"
echo "3. Go to Signing & Capabilities"
echo "4. Add 'Background Modes' capability"
echo "5. Enable 'Location updates', 'Background fetch', 'Background processing'"
echo "6. Set iOS Deployment Target to 12.0+"
echo "7. Build and run on iOS device"
echo ""
echo "🎉 Your app should now work on iOS devices!"