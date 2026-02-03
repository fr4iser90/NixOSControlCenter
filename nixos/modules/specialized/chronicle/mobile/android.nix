{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = systemConfig.modules.specialized.chronicle.mobile.android or {};
in
{
  options.services.chronicle.mobile.android = {
    enable = mkEnableOption "Android mobile app support";

    app = {
      packageName = mkOption {
        type = types.str;
        default = "org.steprecorder.mobile";
        description = "Android package name";
      };

      versionCode = mkOption {
        type = types.int;
        default = 40000;
        description = "Android version code (MAJOR*10000 + MINOR*100 + PATCH)";
      };

      versionName = mkOption {
        type = types.str;
        default = "4.0.0";
        description = "Android version name";
      };

      minSdkVersion = mkOption {
        type = types.int;
        default = 26;
        description = "Minimum Android SDK version (Android 8.0+)";
      };

      targetSdkVersion = mkOption {
        type = types.int;
        default = 34;
        description = "Target Android SDK version (Android 14)";
      };
    };

    build = {
      enableKotlin = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Kotlin support";
      };

      enableJetpackCompose = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Jetpack Compose UI framework";
      };

      buildType = mkOption {
        type = types.enum [ "debug" "release" ];
        default = "release";
        description = "Build type";
      };

      enableProguard = mkOption {
        type = types.bool;
        default = true;
        description = "Enable ProGuard code obfuscation";
      };
    };

    features = {
      enableScreenRecording = mkOption {
        type = types.bool;
        default = true;
        description = "Enable screen recording on Android";
      };

      enableSessionViewer = mkOption {
        type = types.bool;
        default = true;
        description = "Enable session playback viewer";
      };

      enablePushNotifications = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Firebase Cloud Messaging";
      };

      enableOfflineMode = mkOption {
        type = types.bool;
        default = true;
        description = "Enable offline session storage";
      };

      enableCloudSync = mkOption {
        type = types.bool;
        default = true;
        description = "Enable cloud synchronization";
      };
    };

    permissions = mkOption {
      type = types.listOf types.str;
      default = [
        "RECORD_AUDIO"
        "CAMERA"
        "WRITE_EXTERNAL_STORAGE"
        "READ_EXTERNAL_STORAGE"
        "INTERNET"
        "ACCESS_NETWORK_STATE"
      ];
      description = "Required Android permissions";
    };

    signing = {
      keystorePath = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to keystore file for app signing";
      };

      keystorePasswordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to file containing keystore password";
      };

      keyAlias = mkOption {
        type = types.str;
        default = "chronicle";
        description = "Key alias for signing";
      };
    };

    distribution = {
      enableGooglePlay = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Google Play Store distribution";
      };

      enableFDroid = mkOption {
        type = types.bool;
        default = true;
        description = "Enable F-Droid distribution";
      };

      enableDirectDownload = mkOption {
        type = types.bool;
        default = true;
        description = "Enable direct APK download";
      };
    };
  };

  config = mkIf (cfg.enable or false) {
    environment.systemPackages = with pkgs; [
      (writeScriptBin "chronicle-android" ''
        #!${pkgs.bash}/bin/bash
        # Android App Management
        
        set -euo pipefail
        
        APP_NAME="Step Recorder"
        PACKAGE="${cfg.app.packageName}"
        VERSION_CODE=${toString cfg.app.versionCode}
        VERSION_NAME="${cfg.app.versionName}"
        MIN_SDK=${toString cfg.app.minSdkVersion}
        TARGET_SDK=${toString cfg.app.targetSdkVersion}
        
        generate_manifest() {
            cat << EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="$PACKAGE"
    android:versionCode="$VERSION_CODE"
    android:versionName="$VERSION_NAME">

    <uses-sdk
        android:minSdkVersion="$MIN_SDK"
        android:targetSdkVersion="$TARGET_SDK" />

${lib.concatMapStrings (permission: ''
    <uses-permission android:name="android.permission.${permission}" />
'') cfg.permissions}

    <application
        android:name=".StepRecorderApplication"
        android:label="$APP_NAME"
        android:icon="@mipmap/ic_launcher"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:theme="@style/Theme.StepRecorder"
        android:allowBackup="true"
        android:usesCleartextTraffic="false"
        android:networkSecurityConfig="@xml/network_security_config">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:screenOrientation="portrait">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

${if cfg.features.enableScreenRecording then ''
        <service
            android:name=".service.ScreenRecordService"
            android:enabled="true"
            android:exported="false"
            android:foregroundServiceType="mediaProjection" />
'' else ""}

${if cfg.features.enablePushNotifications then ''
        <service
            android:name=".service.FirebaseMessagingService"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT" />
            </intent-filter>
        </service>
'' else ""}

    </application>
</manifest>
EOF
        }
        
        generate_gradle() {
            cat << EOF
plugins {
    id 'com.android.application'
${if cfg.build.enableKotlin then "    id 'org.jetbrains.kotlin.android'" else ""}
}

android {
    namespace '$PACKAGE'
    compileSdk $TARGET_SDK

    defaultConfig {
        applicationId "$PACKAGE"
        minSdk $MIN_SDK
        targetSdk $TARGET_SDK
        versionCode $VERSION_CODE
        versionName "$VERSION_NAME"

        testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            minifyEnabled ${if cfg.build.enableProguard then "true" else "false"}
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
${if cfg.signing.keystorePath != null then ''
            signingConfig signingConfigs.release
'' else ""}
        }
    }

${if cfg.signing.keystorePath != null then ''
    signingConfigs {
        release {
            storeFile file("${toString cfg.signing.keystorePath}")
            keyAlias "${cfg.signing.keyAlias}"
            // Load passwords from environment or gradle.properties
        }
    }
'' else ""}

${if cfg.build.enableJetpackCompose then ''
    buildFeatures {
        compose true
    }
    composeOptions {
        kotlinCompilerExtensionVersion '1.5.8'
    }
'' else ""}

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
${if cfg.build.enableKotlin then ''
    kotlinOptions {
        jvmTarget = '17'
    }
'' else ""}
}

dependencies {
    implementation 'androidx.core:core-ktx:1.12.0'
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'com.google.android.material:material:1.11.0'
    
${if cfg.build.enableJetpackCompose then ''
    implementation platform('androidx.compose:compose-bom:2024.01.00')
    implementation 'androidx.compose.ui:ui'
    implementation 'androidx.compose.material3:material3'
    implementation 'androidx.compose.ui:ui-tooling-preview'
    implementation 'androidx.activity:activity-compose:1.8.2'
'' else ""}

${if cfg.features.enablePushNotifications then ''
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
    implementation 'com.google.firebase:firebase-messaging-ktx'
'' else ""}

${if cfg.features.enableCloudSync then ''
    implementation 'com.squareup.retrofit2:retrofit:2.9.0'
    implementation 'com.squareup.retrofit2:converter-gson:2.9.0'
'' else ""}

    // Testing
    testImplementation 'junit:junit:4.13.2'
    androidTestImplementation 'androidx.test.ext:junit:1.1.5'
    androidTestImplementation 'androidx.test.espresso:espresso-core:3.5.1'
}
EOF
        }
        
        case "''${1:-help}" in
            init)
                echo "Initializing Android project..."
                mkdir -p android-app/{app/src/main/{java,res,assets},gradle/wrapper}
                generate_manifest > android-app/app/src/main/AndroidManifest.xml
                generate_gradle > android-app/app/build.gradle
                echo "✓ Android project initialized in ./android-app"
                ;;
            build)
                echo "Building Android APK..."
                echo "Features enabled:"
                echo "  - Screen Recording: ${if cfg.features.enableScreenRecording then "Yes" else "No"}"
                echo "  - Session Viewer: ${if cfg.features.enableSessionViewer then "Yes" else "No"}"
                echo "  - Push Notifications: ${if cfg.features.enablePushNotifications then "Yes" else "No"}"
                echo "  - Cloud Sync: ${if cfg.features.enableCloudSync then "Yes" else "No"}"
                echo ""
                echo "Build would execute: ./gradlew assemble${cfg.build.buildType}"
                echo "✓ Build configuration ready"
                ;;
            deploy)
                echo "Deploying to Android device..."
                echo "adb install -r app-release.apk"
                echo "✓ Deployment ready"
                ;;
            manifest)
                generate_manifest
                ;;
            gradle)
                generate_gradle
                ;;
            *)
                echo "Usage: chronicle-android {init|build|deploy|manifest|gradle}"
                echo ""
                echo "Commands:"
                echo "  init     - Initialize Android project structure"
                echo "  build    - Build APK"
                echo "  deploy   - Deploy to device"
                echo "  manifest - Generate AndroidManifest.xml"
                echo "  gradle   - Generate build.gradle"
                exit 1
                ;;
        esac
      '')
    ];
  };
}
