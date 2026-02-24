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
            # If target_root is "/", run directly without chroot
            if self.target_root == "/":
                result = subprocess.run(
                    ["bash", script_path],
                    capture_output=True,
                    text=True,
                    timeout=30
                )
            else:
                # Otherwise use chroot for installed system
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
        """
        Main entry point - called by Calamares in SHOW phase (GUI only)
        The actual installation is handled by nixos-control-center-job module
        """
        # Get configuration
        config = libcalamares.job.configuration
        self.repo_path = config.get("repoPath", "/mnt/cdrom/nixos")
        self.shell_nix_path = config.get("shellNixPath", "/etc/nixos/shell.nix")
        scripts_path_config = config.get("scriptsPath", "/etc/nixos/shell/scripts")
        
        # During GUI phase, we run on live system (target_root = "/")
        self.target_root = "/"
        
        # Copy repository from ISO to live system for GUI access
        if os.path.exists("/mnt/cdrom/nixos"):
            try:
                # Copy to a temp location for GUI access
                subprocess.run([
                    "cp", "-r", "/mnt/cdrom/nixos", "/tmp/nixos-control-center-repo"
                ], check=True, timeout=60)
                # Use scripts from copied repo during GUI phase
                self.scripts_path = "/tmp/nixos-control-center-repo/shell/scripts"
                self._statusMessage = "Repository loaded"
            except Exception as e:
                libcalamares.utils.warning(f"Failed to copy repository: {e}")
                self._statusMessage = f"Warning: {e}"
                # Fallback to config path if copy fails
                self.scripts_path = scripts_path_config
        else:
            # Fallback if ISO not mounted
            self.scripts_path = scripts_path_config
        
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
    
    def modifyCalamaresConfig(self):
        """
        Modify the Calamares-generated configuration.nix to import our repository.
        This is called during the exec phase, AFTER Calamares has generated the config.
        """
        config_path = f"{self.target_root}/etc/nixos/configuration.nix"
        
        if not os.path.exists(config_path):
            libcalamares.utils.warning(f"Calamares config not found at {config_path}")
            return False
        
        try:
            # Read the generated config
            with open(config_path, 'r') as f:
                config_content = f.read()
            
            # Check if we already modified it (avoid double modification)
            if "nixos/modules/specialized" in config_content:
                libcalamares.utils.info("Config already contains NixOS Control Center imports")
                return True
            
            # Build the import statement
            # The repository is at /etc/nixos/ (copied from ISO)
            import_statement = '''
  # NixOS Control Center - Import repository modules
  imports = [
    ./nixos/modules/specialized/nixify/config.nix
  ];
'''
            
            # Find the opening brace of the config and insert our import
            # Standard Calamares config starts with: { config, pkgs, ... }:
            # We need to add our import after the opening brace
            if "{ config, pkgs, ... }:" in config_content:
                # Insert after the first line
                lines = config_content.split('\n')
                insert_index = 1
                for i, line in enumerate(lines):
                    if line.strip().startswith('{') and 'config' in line:
                        insert_index = i + 1
                        break
                
                lines.insert(insert_index, import_statement)
                config_content = '\n'.join(lines)
            else:
                # Fallback: append at the beginning
                config_content = import_statement + config_content
            
            # Write modified config
            with open(config_path, 'w') as f:
                f.write(config_content)
            
            libcalamares.utils.info("Successfully modified Calamares configuration.nix")
            return True
            
        except Exception as e:
            libcalamares.utils.warning(f"Failed to modify Calamares config: {e}")
            return False
    
    @pyqtSlot()
    def startSetup(self):
        """Start the actual setup process (GUI only - actual work happens in exec phase)"""
        self._setupRunning = True
        self.setupRunningChanged.emit(True)
        self._setupProgress = 0
        self.setupProgressChanged.emit(0)
        
        # This is just for GUI feedback
        # The actual installation happens in the exec phase via modifyCalamaresConfig()
        self._setupProgress = 50
        self.setupProgressChanged.emit(50)
        self._statusMessage = "Configuration will be applied during installation..."
        self.statusMessageChanged.emit(self._statusMessage)
        
        # Store selection for later use in exec phase
        selection_data = {
            "installType": self.installType,
            "preset": self.selectedPreset,
            "systemType": self.systemType,
            "desktopEnv": self.desktopEnv,
            "features": self.selectedFeatures
        }
        
        # Save to Calamares global storage for exec phase
        libcalamares.globalstorage.insert("nixosControlCenterSelection", selection_data)
        
        self._setupProgress = 100
        self.setupProgressChanged.emit(100)
        self._statusMessage = "Ready for installation"
        self.statusMessageChanged.emit(self._statusMessage)
        
        self._setupRunning = False
        self.setupRunningChanged.emit(False)
        return True
    
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
    """
    Calamares module entry point.
    For viewqml modules: This initializes the backend for QML
    For job modules: This runs the installation logic
    """
    backend = NixOSControlCenter()
    result = backend.run()
    
    # If run() returns a tuple, it's an error message
    if isinstance(result, tuple):
        return result
    
    # None means success
    return None
