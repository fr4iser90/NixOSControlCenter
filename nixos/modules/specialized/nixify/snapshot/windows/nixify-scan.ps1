# Nixify Windows Snapshot Script
# Erfasst installierte Programme und System-Einstellungen für NixOS-Migration

param(
    [string]$OutputFile = "nixify-report.json",
    [switch]$Upload = $false,
    [string]$ServerUrl = ""
)

# Error handling
$ErrorActionPreference = "Stop"

Write-Host "=== Nixify Windows Snapshot ==="
Write-Host ""

# Initialize report
$report = @{
    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    os = "windows"
    version = (Get-CimInstance Win32_OperatingSystem).Version
    build = (Get-CimInstance Win32_OperatingSystem).BuildNumber
    edition = (Get-CimInstance Win32_OperatingSystem).Caption
    hardware = @{}
    programs = @()
    settings = @{}
}

Write-Host "Collecting system information..."

# Hardware-Info
try {
    $cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
    $ram = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    $gpu = (Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notlike "*Basic*" } | Select-Object -First 1).Name
    
    $report.hardware = @{
        cpu = $cpu
        ram = $ram
        gpu = $gpu
    }
    
    Write-Host "  OK: Hardware information collected"
} catch {
    Write-Host "  WARN: Could not collect all hardware information"
}

# Installierte Programme erfassen
Write-Host "Collecting installed programs..."

$programsList = @()

# Windows Registry (Uninstall)
try {
    $registryPrograms = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and $_.DisplayName -notlike "*Update*" -and $_.DisplayName -notlike "*Hotfix*" } |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate
    
    foreach ($prog in $registryPrograms) {
        $programsList += @{
            name = $prog.DisplayName
            version = $prog.DisplayVersion
            publisher = $prog.Publisher
            source = "registry"
        }
    }
    Write-Host "  OK: Registry programs: $($registryPrograms.Count)"
} catch {
    Write-Host "  WARN: Could not read registry"
}

# Program Files
try {
    $programFiles = Get-ChildItem "C:\Program Files" -Directory -ErrorAction SilentlyContinue | Select-Object Name
    $programFilesX86 = Get-ChildItem "C:\Program Files (x86)" -Directory -ErrorAction SilentlyContinue | Select-Object Name
    
    foreach ($dir in ($programFiles + $programFilesX86)) {
        if ($programsList | Where-Object { $_.name -eq $dir.Name }) { continue }
        $programsList += @{
            name = $dir.Name
            source = "programfiles"
        }
    }
    Write-Host "  OK: Program Files directories scanned"
} catch {
    Write-Host "  WARN: Could not scan Program Files"
}

# Chocolatey
if (Get-Command choco -ErrorAction SilentlyContinue) {
    try {
        $chocoPackages = choco list --local-only --limit-output | ForEach-Object {
            $name = ($_ -split '\|')[0]
            if ($programsList | Where-Object { $_.name -eq $name }) { return }
            @{
                name = $name
                source = "chocolatey"
            }
        }
        $programsList += $chocoPackages
        Write-Host "  OK: Chocolatey packages: $($chocoPackages.Count)"
    } catch {
        Write-Host "  WARN: Could not read Chocolatey packages"
    }
}

# Scoop
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    try {
        $scoopApps = scoop list | Select-Object -Skip 1 | ForEach-Object {
            $name = ($_ -split '\s+')[0]
            if ($programsList | Where-Object { $_.name -eq $name }) { return }
            @{
                name = $name
                source = "scoop"
            }
        }
        $programsList += $scoopApps
        Write-Host "  OK: Scoop packages: $($scoopApps.Count)"
    } catch {
        Write-Host "  WARN: Could not read Scoop packages"
    }
}

$report.programs = $programsList

# System-Einstellungen
Write-Host "Collecting system settings..."

try {
    $timezone = (Get-TimeZone).Id
    $locale = (Get-Culture).Name
    $keyboard = (Get-WinUserLanguageList).InputMethodTips -join ", "
    
    $report.settings = @{
        timezone = $timezone
        locale = $locale
        keyboard = $keyboard
        desktop = "windows"
    }
    
    Write-Host "  OK: System settings collected"
} catch {
    Write-Host "  WARN: Could not collect all settings"
}

# JSON-Report generieren
Write-Host ""
Write-Host "Generating report..."

$json = $report | ConvertTo-Json -Depth 10 -Compress
$json | Out-File -FilePath $OutputFile -Encoding UTF8

Write-Host "  OK: Report saved to: $OutputFile"
Write-Host ""

# Summary
Write-Host "=== Summary ==="
Write-Host "  Programs found: $($programsList.Count)"
Write-Host "  CPU: $($report.hardware.cpu)"
Write-Host "  RAM: $([math]::Round($report.hardware.ram / 1GB, 2)) GB"
Write-Host "  GPU: $($report.hardware.gpu)"
Write-Host ""

# Upload option
if ($Upload -and $ServerUrl) {
    Write-Host "Uploading report to server..."
    try {
        $response = Invoke-RestMethod -Uri "$ServerUrl/api/v1/upload" -Method Post -Body $json -ContentType "application/json"
        Write-Host "  OK: Upload successful! Session ID: $($response.session_id)"
    } catch {
        Write-Host "  ERROR: Upload failed: $_"
    }
} elseif ($Upload) {
    Write-Host "  WARN: Upload requested but no server URL provided"
    Write-Host "  Use: -ServerUrl 'http://your-nixos-server:8080'"
}

Write-Host ""
Write-Host "OK: Snapshot complete"
Write-Host "  Review the report and upload manually if needed:"
Write-Host "  curl -X POST http://your-server:8080/api/v1/upload -H 'Content-Type: application/json' -d @$OutputFile"
