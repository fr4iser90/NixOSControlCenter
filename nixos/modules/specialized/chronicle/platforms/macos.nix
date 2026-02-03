{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = systemConfig.modules.specialized.chronicle.platforms.macos or {};
in
{
  options.services.chronicle.platforms.macos = {
    enable = mkEnableOption "macOS platform support";

    build = {
      minimumVersion = mkOption {
        type = types.str;
        default = "13.0";
        description = "Minimum macOS version (Ventura)";
      };

      architecture = mkOption {
        type = types.enum [ "x86_64" "arm64" "universal" ];
        default = "universal";
        description = "Target architecture (Intel, Apple Silicon, or Universal)";
      };

      enableSwiftUI = mkOption {
        type = types.bool;
        default = true;
        description = "Enable SwiftUI for modern interface";
      };
    };

    features = {
      enableScreenRecording = mkOption {
        type = types.bool;
        default = true;
        description = "Enable native macOS screen recording";
      };

      enableMenuBarApp = mkOption {
        type = types.bool;
        default = true;
        description = "Enable menu bar application mode";
      };

      enableNotificationCenter = mkOption {
        type = types.bool;
        default = true;
        description = "Enable macOS Notification Center integration";
      };

      enableSpotlightSearch = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Spotlight search integration";
      };

      enableSiriShortcuts = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Siri Shortcuts integration";
      };

      enableHandoff = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Handoff with iOS devices";
      };
    };

    signing = {
      teamId = mkOption {
        type = types.str;
        default = "";
        description = "Apple Developer Team ID";
      };

      enableNotarization = mkOption {
        type = types.bool;
        default = true;
        description = "Enable app notarization for Gatekeeper";
      };

      enableHardening = mkOption {
        type = types.bool;
        default = true;
        description = "Enable hardened runtime";
      };
    };

    distribution = {
      enableAppStore = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Mac App Store distribution";
      };

      enableHomebrew = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Homebrew cask";
      };

      enableDMG = mkOption {
        type = types.bool;
        default = true;
        description = "Enable DMG disk image distribution";
      };
    };
  };

  config = mkIf (cfg.enable or false) {
    environment.systemPackages = with pkgs; [
      (writeScriptBin "chronicle-macos" ''
        #!${pkgs.bash}/bin/bash
        # macOS Build Script
        
        set -euo pipefail
        
        ARCH="${cfg.build.architecture}"
        MIN_VERSION="${cfg.build.minimumVersion}"
        BUNDLE_ID="org.steprecorder.macos"
        
        generate_info_plist() {
            cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Step Recorder</string>
    <key>CFBundleExecutable</key>
    <string>StepRecorder</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Step Recorder</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>4.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_VERSION</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
${if cfg.features.enableMenuBarApp then ''
    <key>LSUIElement</key>
    <true/>
'' else ""}
${if cfg.features.enableScreenRecording then ''
    <key>NSScreenCaptureDescription</key>
    <string>Step Recorder needs screen recording permission to capture screenshots</string>
    <key>NSCameraUsageDescription</key>
    <string>Step Recorder can optionally record video</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Step Recorder can record audio commentary</string>
'' else ""}
</dict>
</plist>
EOF
        }
        
        generate_entitlements() {
            cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
${if cfg.features.enableScreenRecording then ''
    <key>com.apple.security.device.camera</key>
    <true/>
    <key>com.apple.security.device.audio-input</key>
    <true/>
'' else ""}
${if cfg.signing.enableHardening then ''
    <key>com.apple.security.cs.allow-jit</key>
    <false/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <false/>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <false/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <false/>
'' else ""}
</dict>
</plist>
EOF
        }
        
        generate_podfile() {
            cat << EOF
platform :osx, '$MIN_VERSION'
use_frameworks!

target 'StepRecorder' do
  # Core dependencies
  pod 'Alamofire', '~> 5.8'
  pod 'KeyboardShortcuts', '~> 1.15'
  
${if cfg.features.enableNotificationCenter then ''
  # Notifications
  pod 'UserNotifications'
'' else ""}

  target 'StepRecorderTests' do
    inherit! :search_paths
    pod 'Quick'
    pod 'Nimble'
  end
end
EOF
        }
        
        generate_homebrew_formula() {
            cat << 'RUBY'
class StepRecorder < Formula
  desc "Problem Steps Recorder for macOS"
  homepage "https://github.com/chronicle/chronicle"
  url "https://github.com/chronicle/releases/download/v4.0.0/chronicle-macos.tar.gz"
  sha256 "CHECKSUM_HERE"
  version "4.0.0"
  
  depends_on :macos => :ventura
  
  def install
    bin.install "chronicle"
    prefix.install "StepRecorder.app"
  end
  
  test do
    system "#{bin}/chronicle", "--version"
  end
end
RUBY
        }
        
        case "''${1:-help}" in
            init)
                echo "Initializing macOS project..."
                mkdir -p macos-app/StepRecorder.xcodeproj
                mkdir -p macos-app/StepRecorder/{Resources,Views,ViewModels,Models,Services}
                generate_info_plist > macos-app/StepRecorder/Info.plist
                generate_entitlements > macos-app/StepRecorder/StepRecorder.entitlements
                generate_podfile > macos-app/Podfile
                echo "✓ macOS project initialized in ./macos-app"
                ;;
            build)
                echo "Building for macOS..."
                echo "Architecture: $ARCH"
                echo "Features:"
                echo "  - SwiftUI: ${if cfg.build.enableSwiftUI then "Yes" else "No"}"
                echo "  - Screen Recording: ${if cfg.features.enableScreenRecording then "Yes" else "No"}"
                echo "  - Menu Bar App: ${if cfg.features.enableMenuBarApp then "Yes" else "No"}"
                echo "  - Handoff: ${if cfg.features.enableHandoff then "Yes" else "No"}"
                echo ""
                echo "Build would execute:"
                if [ "$ARCH" = "universal" ]; then
                    echo "xcodebuild -scheme StepRecorder -configuration Release -arch x86_64 -arch arm64 ONLY_ACTIVE_ARCH=NO"
                else
                    echo "xcodebuild -scheme StepRecorder -configuration Release -arch $ARCH"
                fi
                ;;
            package-dmg)
                echo "Creating DMG..."
                echo "create-dmg --volname 'Step Recorder' --window-pos 200 120 --window-size 800 400 --icon-size 100 --icon 'StepRecorder.app' 200 190 --hide-extension 'StepRecorder.app' --app-drop-link 600 185 'StepRecorder-4.0.0.dmg' 'StepRecorder.app'"
                ;;
            sign)
                echo "Signing application..."
${if cfg.signing.teamId != "" then ''
                echo "codesign --force --options runtime --sign '${cfg.signing.teamId}' --entitlements StepRecorder.entitlements StepRecorder.app"
'' else ''
                echo "Code signing requires teamId configuration"
'' fi}
                ;;
            notarize)
${if cfg.signing.enableNotarization then ''
                echo "Submitting for notarization..."
                echo "xcrun notarytool submit StepRecorder-4.0.0.dmg --team-id ${cfg.signing.teamId} --wait"
                echo "xcrun stapler staple StepRecorder.app"
'' else ''
                echo "Notarization not enabled"
'' fi}
                ;;
            homebrew-formula)
                generate_homebrew_formula
                ;;
            *)
                echo "Usage: chronicle-macos {init|build|package-dmg|sign|notarize|homebrew-formula}"
                echo ""
                echo "Commands:"
                echo "  init             - Initialize macOS project"
                echo "  build            - Build macOS application"
                echo "  package-dmg      - Create DMG installer"
                echo "  sign             - Sign application"
                echo "  notarize         - Notarize for Gatekeeper"
                echo "  homebrew-formula - Generate Homebrew formula"
                exit 1
                ;;
        esac
      '')
    ];
  };
}
