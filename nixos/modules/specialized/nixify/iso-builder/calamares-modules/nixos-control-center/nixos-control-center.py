#!/usr/bin/env python3
"""
NixOS Control Center Calamares Module
Provides GUI for NixOS Control Center setup during installation
"""

import libcalamares
import subprocess
import os
import json
import threading
from PyQt5.QtCore import QObject, pyqtSignal, pyqtProperty, pyqtSlot, QThread

class HardwareCheckThread(QThread):
    """Thread for running hardware checks"""
    cpuStatusChanged = pyqtSignal(str, str)  # status, message
    gpuStatusChanged = pyqtSignal(str, str)
    memoryStatusChanged = pyqtSignal(str, str)
    storageStatusChanged = pyqtSignal(str, str)
    
    def __init__(self, target_root, scripts_path):
        super().__init__()
        self.target_root = target_root
        self.scripts_path = scripts_path
    
    def run(self):
        """Run hardware checks"""
        checks_path = f"{self.target_root}{self.scripts_path}/checks/hardware"
        
        # CPU Check
        self.cpuStatusChanged.emit("checking", "Checking CPU...")
        result = self.run_check(f"{checks_path}/cpu.sh")
        if result[0] == 0:
            # Extract CPU info from output
            cpu_info = result[1].split('\n')[0] if result[1] else "CPU detected"
            self.cpuStatusChanged.emit("success", cpu_info)
        else:
            self.cpuStatusChanged.emit("error", "CPU check failed")
        
        # GPU Check
        self.gpuStatusChanged.emit("checking", "Checking GPU...")
        result = self.run_check(f"{checks_path}/gpu.sh")
        if result[0] == 0:
            gpu_info = result[1].split('\n')[0] if result[1] else "GPU detected"
            self.gpuStatusChanged.emit("success", gpu_info)
        else:
            self.gpuStatusChanged.emit("error", "GPU check failed")
        
        # Memory Check
        self.memoryStatusChanged.emit("checking", "Checking Memory...")
        result = self.run_check(f"{checks_path}/memory.sh")
        if result[0] == 0:
            memory_info = result[1].split('\n')[0] if result[1] else "Memory detected"
            self.memoryStatusChanged.emit("success", memory_info)
        else:
            self.memoryStatusChanged.emit("error", "Memory check failed")
        
        # Storage Check
        self.storageStatusChanged.emit("checking", "Checking Storage...")
        result = self.run_check(f"{checks_path}/storage.sh")
        if result[0] == 0:
            storage_info = result[1].split('\n')[0] if result[1] else "Storage detected"
            self.storageStatusChanged.emit("success", storage_info)
        else:
            self.storageStatusChanged.emit("error", "Storage check failed")
    
    def run_check(self, script_path):
        """Run a check script"""
        try:
            result = subprocess.run(
                ["chroot", self.target_root, "bash", script_path],
                capture_output=True,
                text=True,
                timeout=30
            )
            return (result.returncode, result.stdout)
        except subprocess.TimeoutExpired:
            return (1, "Check timed out")
        except Exception as e:
            return (1, str(e))


class NixOSControlCenter(QObject):
    """Backend for NixOS Control Center Calamares Module"""
    
    # Signals for QML
    statusMessageChanged = pyqtSignal(str)
    currentPageChanged = pyqtSignal(int)
    hardwareChecksCompleteChanged = pyqtSignal(bool)
    setupRunningChanged = pyqtSignal(bool)
    setupProgressChanged = pyqtSignal(int)
    
    # Hardware check signals
    cpuStatusChanged = pyqtSignal(str, str)
    gpuStatusChanged = pyqtSignal(str, str)
    memoryStatusChanged = pyqtSignal(str, str)
    storageStatusChanged = pyqtSignal(str, str)
    
    def __init__(self):
        super().__init__()
        self._statusMessage = "Ready"
        self._currentPage = 0
        self._hardwareChecksComplete = False
        self._setupRunning = False
        self._setupProgress = 0
        self.target_root = None
        self.repo_path = None
        self.shell_nix_path = None
        self.scripts_path = None
        
        # Configuration
        self.installType = ""  # "presets", "custom", "advanced"
        self.selectedPreset = ""
        self.systemType = ""  # "desktop", "server"
        self.desktopEnv = ""  # "plasma", "gnome", "xfce", ""
        self.selectedFeatures = []
        
        # Hardware check thread
        self.checkThread = None
    
    @pyqtProperty(str, notify=statusMessageChanged)
    def statusMessage(self):
        return self._statusMessage
    
    @pyqtProperty(int, notify=currentPageChanged)
    def currentPage(self):
        return self._currentPage
    
    @pyqtProperty(bool, notify=hardwareChecksCompleteChanged)
    def hardwareChecksComplete(self):
        return self._hardwareChecksComplete
    
    @pyqtProperty(bool, notify=setupRunningChanged)
    def setupRunning(self):
        return self._setupRunning
    
    @pyqtProperty(int, notify=setupProgressChanged)
    def setupProgress(self):
        return self._setupProgress
    
    def run(self):
        """Main entry point - called by Calamares"""
        # Get target root from Calamares
        self.target_root = libcalamares.globalstorage.value("rootMountPoint")
        if not self.target_root:
            libcalamares.utils.warning("No rootMountPoint found")
            return False
        
        # Get configuration
        config = libcalamares.job.configuration
        self.repo_path = config.get("repoPath", "/mnt/cdrom/nixos")
        self.shell_nix_path = config.get("shellNixPath", "/etc/nixos/shell.nix")
        self.scripts_path = config.get("scriptsPath", "/etc/nixos/shell/scripts")
        
        # Copy repository from ISO if it exists
        if os.path.exists("/mnt/cdrom/nixos"):
            try:
                subprocess.run([
                    "cp", "-r", "/mnt/cdrom/nixos/*", f"{self.target_root}/etc/nixos/"
                ], check=True, timeout=60)
                self._statusMessage = "Repository copied successfully"
            except Exception as e:
                libcalamares.utils.warning(f"Failed to copy repository: {e}")
                self._statusMessage = f"Warning: {e}"
        
        # Start hardware checks if enabled
        if config.get("enableHardwareChecks", True):
            self.startHardwareChecks()
        
        # Store backend in global storage for QML access
        libcalamares.globalstorage.insert("nixosControlCenter", self)
        
        return True
    
    @pyqtSlot()
    def startHardwareChecks(self):
        """Start hardware checks in background thread"""
        if self.checkThread and self.checkThread.isRunning():
            return
        
        self.checkThread = HardwareCheckThread(self.target_root, self.scripts_path)
        self.checkThread.cpuStatusChanged.connect(self.cpuStatusChanged.emit)
        self.checkThread.gpuStatusChanged.connect(self.gpuStatusChanged.emit)
        self.checkThread.memoryStatusChanged.connect(self.memoryStatusChanged.emit)
        self.checkThread.storageStatusChanged.connect(self.storageStatusChanged.emit)
        self.checkThread.finished.connect(self.onHardwareChecksComplete)
        self.checkThread.start()
    
    def onHardwareChecksComplete(self):
        """Called when hardware checks are complete"""
        self._hardwareChecksComplete = True
        self.hardwareChecksCompleteChanged.emit(True)
        self._statusMessage = "Hardware checks completed"
        self.statusMessageChanged.emit(self._statusMessage)
    
    @pyqtSlot(str)
    def setInstallType(self, install_type):
        """Set installation type (presets, custom, advanced)"""
        self.installType = install_type
        self._statusMessage = f"Installation type: {install_type}"
        self.statusMessageChanged.emit(self._statusMessage)
    
    @pyqtSlot(str)
    def setPreset(self, preset):
        """Set selected preset"""
        self.selectedPreset = preset
        self._statusMessage = f"Selected preset: {preset}"
        self.statusMessageChanged.emit(self._statusMessage)
    
    @pyqtSlot(str)
    def setSystemType(self, system_type):
        """Set system type (desktop, server)"""
        self.systemType = system_type
        self._statusMessage = f"System type: {system_type}"
        self.statusMessageChanged.emit(self._statusMessage)
    
    @pyqtSlot(str)
    def setDesktopEnv(self, desktop_env):
        """Set desktop environment"""
        self.desktopEnv = desktop_env
        self._statusMessage = f"Desktop environment: {desktop_env or 'None'}"
        self.statusMessageChanged.emit(self._statusMessage)
    
    @pyqtSlot(str, bool)
    def toggleFeature(self, feature, enabled):
        """Toggle a feature on/off"""
        if enabled:
            if feature not in self.selectedFeatures:
                self.selectedFeatures.append(feature)
        else:
            if feature in self.selectedFeatures:
                self.selectedFeatures.remove(feature)
        
        # Handle conflicts (e.g., docker/podman)
        conflicts = {
            "docker": ["podman"],
            "podman": ["docker"],
            "plasma": ["gnome", "xfce"],
            "gnome": ["plasma", "xfce"],
            "xfce": ["plasma", "gnome"]
        }
        
        if feature in conflicts:
            for conflict in conflicts[feature]:
                if conflict in self.selectedFeatures:
                    self.selectedFeatures.remove(conflict)
        
        # Handle dependencies (e.g., virt-manager needs qemu-vm)
        dependencies = {
            "virt-manager": ["qemu-vm"]
        }
        
        if feature in dependencies and enabled:
            for dep in dependencies[feature]:
                if dep not in self.selectedFeatures:
                    self.selectedFeatures.append(dep)
        
        self._statusMessage = f"Features: {', '.join(self.selectedFeatures)}"
        self.statusMessageChanged.emit(self._statusMessage)
    
    @pyqtSlot()
    def startSetup(self):
        """Start the actual setup process"""
        self._setupRunning = True
        self.setupRunningChanged.emit(True)
        self._setupProgress = 0
        self.setupProgressChanged.emit(0)
        
        try:
            # Build selection string based on install type
            selection_string = ""
            
            if self.installType == "presets":
                # Preset installation - just the preset name
                selection_string = self.selectedPreset
            elif self.installType == "custom":
                # Custom installation - format: "systemType feature1 feature2 ..."
                features_list = []
                if self.desktopEnv:
                    features_list.append(self.desktopEnv)
                features_list.extend(self.selectedFeatures)
                selection_string = f"{self.systemType} {' '.join(features_list)}"
            else:
                # Advanced options - would need more logic
                selection_string = "Advanced"
            
            # Create a script that will be executed in chroot
            setup_script = f"""#!/bin/bash
set -euo pipefail
cd /etc/nixos
export CORE_DIR=/etc/nixos/shell/scripts/core
export SETUP_DIR=/etc/nixos/shell/scripts/setup
export CHECKS_DIR=/etc/nixos/shell/scripts/checks
export SYSTEM_CONFIG_FILE=/etc/nixos/configs/system-config.nix
export NIXOS_CONFIG_DIR=/etc/nixos

# Source the installer
source /etc/nixos/shell/scripts/core/imports.sh

# Run the installer with our selection
echo "{selection_string}" | /etc/nixos/shell/scripts/core/init.sh
"""
            
            # Write script to target system
            script_path = f"{self.target_root}/tmp/nixos-control-center-setup.sh"
            os.makedirs(f"{self.target_root}/tmp", exist_ok=True)
            with open(script_path, 'w') as f:
                f.write(setup_script)
            os.chmod(script_path, 0o755)
            
            # Run setup
            self._setupProgress = 25
            self.setupProgressChanged.emit(25)
            self._statusMessage = "Generating configuration..."
            self.statusMessageChanged.emit(self._statusMessage)
            
            # Execute setup script
            result = subprocess.run(
                ["chroot", self.target_root, "bash", "/tmp/nixos-control-center-setup.sh"],
                capture_output=True,
                text=True,
                timeout=600
            )
            
            self._setupProgress = 75
            self.setupProgressChanged.emit(75)
            self._statusMessage = "Building NixOS configuration..."
            self.statusMessageChanged.emit(self._statusMessage)
            
            # The deploy_config in init.sh should handle the build
            # We just wait for it to complete
            
            self._setupProgress = 100
            self.setupProgressChanged.emit(100)
            
            if result.returncode == 0:
                self._statusMessage = "Setup completed successfully"
                self.statusMessageChanged.emit(self._statusMessage)
                return True
            else:
                self._statusMessage = f"Setup failed: {result.stderr[:200]}"
                self.statusMessageChanged.emit(self._statusMessage)
                return False
                
        except subprocess.TimeoutExpired:
            self._statusMessage = "Setup timed out"
            self.statusMessageChanged.emit(self._statusMessage)
            return False
        except Exception as e:
            self._statusMessage = f"Setup error: {e}"
            self.statusMessageChanged.emit(self._statusMessage)
            return False
        finally:
            self._setupRunning = False
            self.setupRunningChanged.emit(False)
    
    @pyqtSlot(int)
    def goToPage(self, page):
        """Navigate to a specific page"""
        self._currentPage = page
        self.currentPageChanged.emit(page)
    
    @pyqtProperty('QStringList', constant=True)
    def installTypeOptions(self):
        """Return installation type options"""
        return ["📦 Presets", "🔧 Custom Setup", "⚙️ Advanced Options"]
    
    @pyqtProperty('QStringList', constant=True)
    def systemPresets(self):
        """Return system presets"""
        return ["Desktop", "Server", "Homelab Server"]
    
    @pyqtProperty('QStringList', constant=True)
    def devicePresets(self):
        """Return device presets"""
        return ["Jetson Nano"]
    
    @pyqtProperty('QStringList', constant=True)
    def systemTypes(self):
        """Return system types"""
        return ["Desktop", "Server"]
    
    @pyqtProperty('QStringList', constant=True)
    def desktopEnvironments(self):
        """Return desktop environments"""
        return ["Plasma (KDE)", "GNOME", "XFCE", "None"]
    
    @pyqtProperty('QVariantMap', constant=True)
    def featureGroups(self):
        """Return feature groups"""
        return {
            "Development": ["Web Development", "Game Development", "Python Development", "System Development"],
            "Gaming & Media": ["Streaming", "Emulation"],
            "Containerization": ["Docker", "Podman"],
            "Services": ["Database", "Web Server", "Mail Server"],
            "Virtualization": ["QEMU/KVM", "Virt Manager"]
        }


def run():
    """Calamares module entry point"""
    backend = NixOSControlCenter()
    if not backend.run():
        return ("Failed to initialize NixOS Control Center module", "")
    
    return None
