{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = systemConfig.modules.specialized.chronicle.platforms.windows or {};
in
{
  options.services.chronicle.platforms.windows = {
    enable = mkEnableOption "Windows platform support";

    build = {
      architecture = mkOption {
        type = types.enum [ "x64" "x86" "arm64" ];
        default = "x64";
        description = "Target Windows architecture";
      };

      minimumVersion = mkOption {
        type = types.str;
        default = "10.0.19041.0";
        description = "Minimum Windows version (Windows 10 20H1)";
      };

      enableMSIX = mkOption {
        type = types.bool;
        default = true;
        description = "Enable MSIX packaging for Microsoft Store";
      };

      enablePortable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable portable (zip) distribution";
      };
    };

    features = {
      enableNativeRecording = mkOption {
        type = types.bool;
        default = true;
        description = "Enable native Windows screen recording (Graphics Capture API)";
      };

      enablePowerShellIntegration = mkOption {
        type = types.bool;
        default = true;
        description = "Enable PowerShell module integration";
      };

      enableTaskScheduler = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Windows Task Scheduler integration";
      };

      enableEventLog = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Windows Event Log integration";
      };

      enableWinUI3 = mkOption {
        type = types.bool;
        default = true;
        description = "Enable WinUI 3 modern interface";
      };
    };

    signing = {
      certificatePath = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to code signing certificate (.pfx)";
      };

      timestampServer = mkOption {
        type = types.str;
        default = "http://timestamp.digicert.com";
        description = "Timestamp server for code signing";
      };
    };

    distribution = {
      enableMicrosoftStore = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Microsoft Store distribution";
      };

      enableWinget = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Winget package manager";
      };

      enableChocolatey = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Chocolatey package manager";
      };
    };
  };

  config = mkIf (cfg.enable or false) {
    environment.systemPackages = with pkgs; [
      (writeScriptBin "chronicle-windows" ''
        #!${pkgs.bash}/bin/bash
        # Windows Build Script Generator
        
        set -euo pipefail
        
        ARCH="${cfg.build.architecture}"
        MIN_VERSION="${cfg.build.minimumVersion}"
        
        generate_csproj() {
            cat << EOF
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>net8.0-windows10.0.19041.0</TargetFramework>
    <TargetPlatformMinVersion>${cfg.build.minimumVersion}</TargetPlatformMinVersion>
    <RootNamespace>StepRecorder.Windows</RootNamespace>
    <ApplicationManifest>app.manifest</ApplicationManifest>
    <Platforms>$ARCH</Platforms>
    <RuntimeIdentifiers>win-$ARCH</RuntimeIdentifiers>
    <PublishReadyToRun>true</PublishReadyToRun>
    <PublishSingleFile>true</PublishSingleFile>
    <SelfContained>true</SelfContained>
    <UseWinUI>true</UseWinUI>
    <Version>4.0.0</Version>
    <Company>Step Recorder Project</Company>
    <Product>Step Recorder</Product>
  </PropertyGroup>

  <ItemGroup>
${if cfg.features.enableWinUI3 then ''
    <PackageReference Include="Microsoft.WindowsAppSDK" Version="1.5.240227000" />
    <PackageReference Include="Microsoft.Windows.SDK.BuildTools" Version="10.0.22621.756" />
'' else ""}
${if cfg.features.enableNativeRecording then ''
    <PackageReference Include="Microsoft.Graphics.Win2D" Version="1.2.0" />
'' else ""}
    <PackageReference Include="CommunityToolkit.Mvvm" Version="8.2.2" />
  </ItemGroup>
</Project>
EOF
        }
        
        generate_appxmanifest() {
            cat << EOF
<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
         xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
         xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities">
  <Identity Name="StepRecorder" 
            Publisher="CN=StepRecorder" 
            Version="4.0.0.0" 
            ProcessorArchitecture="$ARCH" />
  <Properties>
    <DisplayName>Step Recorder</DisplayName>
    <PublisherDisplayName>Step Recorder Project</PublisherDisplayName>
    <Logo>Assets\StoreLogo.png</Logo>
  </Properties>
  <Dependencies>
    <TargetDeviceFamily Name="Windows.Desktop" MinVersion="$MIN_VERSION" MaxVersionTested="10.0.22621.0" />
  </Dependencies>
  <Resources>
    <Resource Language="en-US" />
  </Resources>
  <Applications>
    <Application Id="StepRecorder" Executable="StepRecorder.exe" EntryPoint="Windows.FullTrustApplication">
      <uap:VisualElements DisplayName="Step Recorder" 
                          Description="Problem Steps Recorder for Windows"
                          Square150x150Logo="Assets\Square150x150Logo.png"
                          Square44x44Logo="Assets\Square44x44Logo.png"
                          BackgroundColor="transparent">
      </uap:VisualElements>
    </Application>
  </Applications>
  <Capabilities>
${if cfg.features.enableNativeRecording then ''
    <rescap:Capability Name="graphicsCapture" />
'' else ""}
    <Capability Name="internetClient" />
  </Capabilities>
</Package>
EOF
        }
        
        generate_powershell_module() {
            cat << 'EOF'
# Step Recorder PowerShell Module

function Start-StepRecording {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$SessionName = "recording-$(Get-Date -Format 'yyyyMMdd-HHmmss')",
        
        [Parameter(Mandatory=$false)]
        [switch]$EnableVideo,
        
        [Parameter(Mandatory=$false)]
        [switch]$EnableAudio
    )
    
    Write-Host "Starting Step Recorder session: $SessionName" -ForegroundColor Green
    & chronicle.exe start --name $SessionName $(if($EnableVideo){" --video"}) $(if($EnableAudio){" --audio"})
}

function Stop-StepRecording {
    [CmdletBinding()]
    param()
    
    Write-Host "Stopping Step Recorder..." -ForegroundColor Yellow
    & chronicle.exe stop
}

function Get-StepRecordingSessions {
    [CmdletBinding()]
    param()
    
    & chronicle.exe list
}

Export-ModuleMember -Function Start-StepRecording, Stop-StepRecording, Get-StepRecordingSessions
EOF
        }
        
        case "''${1:-help}" in
            init)
                echo "Initializing Windows project..."
                mkdir -p windows-app/{Assets,Properties,Services,ViewModels,Views}
                generate_csproj > windows-app/StepRecorder.csproj
${if cfg.build.enableMSIX then ''
                generate_appxmanifest > windows-app/Package.appxmanifest
'' else ""}
${if cfg.features.enablePowerShellIntegration then ''
                mkdir -p windows-app/PowerShell
                generate_powershell_module > windows-app/PowerShell/StepRecorder.psm1
'' else ""}
                echo "✓ Windows project initialized in ./windows-app"
                ;;
            build)
                echo "Building for Windows..."
                echo "Architecture: $ARCH"
                echo "Features:"
                echo "  - WinUI 3: ${if cfg.features.enableWinUI3 then "Yes" else "No"}"
                echo "  - Native Recording: ${if cfg.features.enableNativeRecording then "Yes" else "No"}"
                echo "  - PowerShell: ${if cfg.features.enablePowerShellIntegration then "Yes" else "No"}"
                echo "  - MSIX Package: ${if cfg.build.enableMSIX then "Yes" else "No"}"
                echo ""
                echo "Build would execute:"
                echo "dotnet publish -c Release -r win-$ARCH --self-contained"
                ;;
            package-msix)
                echo "Creating MSIX package..."
                echo "makeappx pack /d windows-app/bin/Release/net8.0-windows/win-$ARCH/publish /p StepRecorder.msix"
${if cfg.signing.certificatePath != null then ''
                echo "signtool sign /f ${toString cfg.signing.certificatePath} /tr ${cfg.signing.timestampServer} /td sha256 StepRecorder.msix"
'' else ""}
                ;;
            package-portable)
                echo "Creating portable ZIP..."
                echo "7z a StepRecorder-windows-$ARCH-portable.zip ./windows-app/bin/Release/net8.0-windows/win-$ARCH/publish/*"
                ;;
            powershell-module)
                generate_powershell_module
                ;;
            *)
                echo "Usage: chronicle-windows {init|build|package-msix|package-portable|powershell-module}"
                echo ""
                echo "Commands:"
                echo "  init             - Initialize Windows project"
                echo "  build            - Build Windows application"
                echo "  package-msix     - Create MSIX package"
                echo "  package-portable - Create portable ZIP"
                echo "  powershell-module - Generate PowerShell module"
                exit 1
                ;;
        esac
      '')
    ];
  };
}
