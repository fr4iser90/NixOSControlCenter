{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = systemConfig.modules.specialized.chronicle.mobile.ios or {};
in
{
  options.services.chronicle.mobile.ios = {
    enable = mkEnableOption "iOS mobile app support";

    app = {
      bundleIdentifier = mkOption {
        type = types.str;
        default = "org.steprecorder.mobile";
        description = "iOS bundle identifier";
      };

      version = mkOption {
        type = types.str;
        default = "4.0.0";
        description = "iOS app version";
      };

      buildNumber = mkOption {
        type = types.str;
        default = "1";
        description = "iOS build number";
      };

      minimumOSVersion = mkOption {
        type = types.str;
        default = "15.0";
        description = "Minimum iOS version";
      };

      targetOSVersion = mkOption {
        type = types.str;
        default = "17.0";
        description = "Target iOS version";
      };
    };

    build = {
      enableSwiftUI = mkOption {
        type = types.bool;
        default = true;
        description = "Enable SwiftUI framework";
      };

      enableCombine = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Combine framework";
      };

      scheme = mkOption {
        type = types.enum [ "Debug" "Release" ];
        default = "Release";
        description = "Build scheme";
      };
    };

    features = {
      enableScreenRecording = mkOption {
        type = types.bool;
        default = true;
        description = "Enable screen recording via ReplayKit";
      };

      enableSessionViewer = mkOption {
        type = types.bool;
        default = true;
        description = "Enable session playback viewer";
      };

      enablePushNotifications = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Apple Push Notification service";
      };

      enableiCloudSync = mkOption {
        type = types.bool;
        default = true;
        description = "Enable iCloud synchronization";
      };

      enableWidgets = mkOption {
        type = types.bool;
        default = true;
        description = "Enable iOS widgets";
      };
    };

    capabilities = mkOption {
      type = types.listOf types.str;
      default = [
        "com.apple.security.application-groups"
        "com.apple.developer.icloud-container-identifiers"
        "aps-environment"
      ];
      description = "Required iOS capabilities";
    };

    signing = {
      teamId = mkOption {
        type = types.str;
        default = "";
        description = "Apple Developer Team ID";
      };

      profilePath = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to provisioning profile";
      };

      certificatePath = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to signing certificate";
      };
    };

    distribution = {
      enableAppStore = mkOption {
        type = types.bool;
        default = true;
        description = "Enable App Store distribution";
      };

      enableTestFlight = mkOption {
        type = types.bool;
        default = true;
        description = "Enable TestFlight beta testing";
      };

      enableEnterprise = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Enterprise distribution";
      };
    };
  };

  config = mkIf (cfg.enable or false) {
    environment.systemPackages = with pkgs; [
      (writeScriptBin "chronicle-ios" ''
        #!${pkgs.bash}/bin/bash
        # iOS App Management
        
        set -euo pipefail
        
        APP_NAME="Step Recorder"
        BUNDLE_ID="${cfg.app.bundleIdentifier}"
        VERSION="${cfg.app.version}"
        BUILD_NUMBER="${cfg.app.buildNumber}"
        MIN_IOS="${cfg.app.minimumOSVersion}"
        TARGET_IOS="${cfg.app.targetOSVersion}"
        
        generate_info_plist() {
            cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>\$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>\$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>armv7</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
${if cfg.features.enableScreenRecording then ''
    <key>NSPhotoLibraryUsageDescription</key>
    <string>Save screen recordings to your photo library</string>
    <key>NSCameraUsageDescription</key>
    <string>Record video during session capture</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Record audio commentary</string>
'' else ""}
${if cfg.features.enablePushNotifications then ''
    <key>UIBackgroundModes</key>
    <array>
        <string>remote-notification</string>
    </array>
'' else ""}
</dict>
</plist>
EOF
        }
        
        generate_podfile() {
            cat << EOF
platform :ios, '$MIN_IOS'
use_frameworks!

target 'StepRecorder' do
  # Core dependencies
  pod 'Alamofire', '~> 5.8'
  
${if cfg.features.enableiCloudSync then ''
  # iCloud sync
  pod 'CloudKit'
'' else ""}

${if cfg.features.enablePushNotifications then ''
  # Push notifications
  pod 'Firebase/Messaging'
'' else ""}

  # UI
  pod 'SnapKit', '~> 5.6.0'
  
  target 'StepRecorderTests' do
    inherit! :search_paths
    pod 'Quick'
    pod 'Nimble'
  end
end
EOF
        }
        
        generate_xcodeproj_settings() {
            cat << EOF
// Xcode Project Settings
PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID
MARKETING_VERSION = $VERSION
CURRENT_PROJECT_VERSION = $BUILD_NUMBER
IPHONEOS_DEPLOYMENT_TARGET = $MIN_IOS
SWIFT_VERSION = 5.9

${if cfg.signing.teamId != "" then ''
DEVELOPMENT_TEAM = ${cfg.signing.teamId}
CODE_SIGN_STYLE = Manual
'' else ""}

// Build Settings
ENABLE_BITCODE = NO
SWIFT_COMPILATION_MODE = wholemodule
SWIFT_OPTIMIZATION_LEVEL = -O

// Capabilities
${concatStringsSep "\n" (map (cap: "ENTITLEMENTS_${cap} = YES") cfg.capabilities)}
EOF
        }
        
        case "''${1:-help}" in
            init)
                echo "Initializing iOS project..."
                mkdir -p ios-app/StepRecorder/{Resources,Views,ViewModels,Models,Services}
                generate_info_plist > ios-app/StepRecorder/Info.plist
                generate_podfile > ios-app/Podfile
                echo "✓ iOS project initialized in ./ios-app"
                echo ""
                echo "Next steps:"
                echo "  1. cd ios-app"
                echo "  2. pod install"
                echo "  3. open StepRecorder.xcworkspace"
                ;;
            build)
                echo "Building iOS app..."
                echo "Features enabled:"
                echo "  - SwiftUI: ${if cfg.build.enableSwiftUI then "Yes" else "No"}"
                echo "  - Screen Recording: ${if cfg.features.enableScreenRecording then "Yes" else "No"}"
                echo "  - Session Viewer: ${if cfg.features.enableSessionViewer then "Yes" else "No"}"
                echo "  - Push Notifications: ${if cfg.features.enablePushNotifications then "Yes" else "No"}"
                echo "  - iCloud Sync: ${if cfg.features.enableiCloudSync then "Yes" else "No"}"
                echo "  - Widgets: ${if cfg.features.enableWidgets then "Yes" else "No"}"
                echo ""
                echo "Build would execute:"
                echo "xcodebuild -scheme StepRecorder -configuration ${cfg.build.scheme} -archivePath build/StepRecorder.xcarchive archive"
                echo "✓ Build configuration ready"
                ;;
            archive)
                echo "Creating iOS archive..."
                echo "xcodebuild -exportArchive -archivePath build/StepRecorder.xcarchive -exportPath build/ipa -exportOptionsPlist ExportOptions.plist"
                ;;
            deploy-testflight)
                echo "Uploading to TestFlight..."
                echo "xcrun altool --upload-app -f build/ipa/StepRecorder.ipa -t ios -u <apple-id> -p <app-specific-password>"
                ;;
            info-plist)
                generate_info_plist
                ;;
            podfile)
                generate_podfile
                ;;
            *)
                echo "Usage: chronicle-ios {init|build|archive|deploy-testflight|info-plist|podfile}"
                echo ""
                echo "Commands:"
                echo "  init              - Initialize iOS project structure"
                echo "  build             - Build app"
                echo "  archive           - Create archive for distribution"
                echo "  deploy-testflight - Upload to TestFlight"
                echo "  info-plist        - Generate Info.plist"
                echo "  podfile           - Generate Podfile"
                exit 1
                ;;
        esac
      '')
    ];
  };
}
