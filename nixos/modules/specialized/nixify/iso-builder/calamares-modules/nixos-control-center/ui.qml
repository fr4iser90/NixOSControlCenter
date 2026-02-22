import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.calamares.ui 1.0

Item {
    id: root
    
    property var backend: null
    
    // Initialize backend from Calamares
    Component.onCompleted: {
        backend = Calamares.globalStorage.value("nixosControlCenter")
        if (backend) {
            // Connect signals
            backend.statusMessageChanged.connect(function(msg) {
                statusLabel.text = msg
            })
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20
        
        // Header
        Label {
            text: "NixOS Control Center Setup"
            font.pixelSize: 24
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }
        
        // Status Label
        Label {
            id: statusLabel
            text: backend ? backend.statusMessage : "Initializing..."
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        
        // Page Stack
        StackLayout {
            id: pageStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: backend ? backend.currentPage : 0
            
            // Page 0: Hardware Checks
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 15
                    
                    Label {
                        text: "🔍 Hardware Verification"
                        font.pixelSize: 18
                        font.bold: true
                    }
                    
                    // CPU Check
                    GroupBox {
                        title: "CPU Check"
                        Layout.fillWidth: true
                        
                        ColumnLayout {
                            anchors.fill: parent
                            
                            ProgressBar {
                                id: cpuProgress
                                Layout.fillWidth: true
                                indeterminate: cpuStatus.text === "Checking..."
                                value: cpuStatus.text === "✅ OK" ? 1.0 : 0.0
                            }
                            
                            Label {
                                id: cpuStatus
                                text: "Checking..."
                            }
                        }
                    }
                    
                    // GPU Check
                    GroupBox {
                        title: "GPU Check"
                        Layout.fillWidth: true
                        
                        ColumnLayout {
                            anchors.fill: parent
                            
                            ProgressBar {
                                id: gpuProgress
                                Layout.fillWidth: true
                                indeterminate: gpuStatus.text === "Checking..."
                                value: gpuStatus.text === "✅ OK" ? 1.0 : 0.0
                            }
                            
                            Label {
                                id: gpuStatus
                                text: "Checking..."
                            }
                        }
                    }
                    
                    // Memory Check
                    GroupBox {
                        title: "Memory Check"
                        Layout.fillWidth: true
                        
                        ColumnLayout {
                            anchors.fill: parent
                            
                            ProgressBar {
                                id: memoryProgress
                                Layout.fillWidth: true
                                indeterminate: memoryStatus.text === "Checking..."
                                value: memoryStatus.text === "✅ OK" ? 1.0 : 0.0
                            }
                            
                            Label {
                                id: memoryStatus
                                text: "Checking..."
                            }
                        }
                    }
                    
                    // Storage Check
                    GroupBox {
                        title: "Storage Check"
                        Layout.fillWidth: true
                        
                        ColumnLayout {
                            anchors.fill: parent
                            
                            ProgressBar {
                                id: storageProgress
                                Layout.fillWidth: true
                                indeterminate: storageStatus.text === "Checking..."
                                value: storageStatus.text === "✅ OK" ? 1.0 : 0.0
                            }
                            
                            Label {
                                id: storageStatus
                                text: "Checking..."
                            }
                        }
                    }
                    
                    Button {
                        text: "Continue"
                        enabled: backend && backend.hardwareChecksComplete
                        Layout.alignment: Qt.AlignHCenter
                        onClicked: {
                            if (backend) {
                                backend.goToPage(1)
                            }
                        }
                    }
                    
                    // Auto-start checks on page load
                    Component.onCompleted: {
                        if (backend) {
                            backend.startHardwareChecks()
                        }
                    }
                }
                
                // Connect hardware check signals
                Connections {
                    target: backend
                    function onCpuStatusChanged(status, message) {
                        cpuStatus.text = message
                        if (status === "success") {
                            cpuProgress.value = 1.0
                        }
                    }
                    function onGpuStatusChanged(status, message) {
                        gpuStatus.text = message
                        if (status === "success") {
                            gpuProgress.value = 1.0
                        }
                    }
                    function onMemoryStatusChanged(status, message) {
                        memoryStatus.text = message
                        if (status === "success") {
                            memoryProgress.value = 1.0
                        }
                    }
                    function onStorageStatusChanged(status, message) {
                        storageStatus.text = message
                        if (status === "success") {
                            storageProgress.value = 1.0
                        }
                    }
                }
            }
            
            // Page 1: Installation Type
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 15
                    
                    Label {
                        text: "Choose Installation Method"
                        font.pixelSize: 18
                        font.bold: true
                    }
                    
                    Label {
                        text: "Select how you want to configure NixOS:"
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                    
                    RadioButton {
                        id: presetRadio
                        text: "📦 Presets"
                        Layout.fillWidth: true
                        onCheckedChanged: {
                            if (checked && backend) {
                                backend.setInstallType("presets")
                            }
                        }
                    }
                    
                    Label {
                        text: "    Quick setup with predefined configs"
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                    
                    RadioButton {
                        id: customRadio
                        text: "🔧 Custom Setup"
                        Layout.fillWidth: true
                        onCheckedChanged: {
                            if (checked && backend) {
                                backend.setInstallType("custom")
                            }
                        }
                    }
                    
                    Label {
                        text: "    Configure everything manually"
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                    
                    RadioButton {
                        id: advancedRadio
                        text: "⚙️ Advanced Options"
                        Layout.fillWidth: true
                        onCheckedChanged: {
                            if (checked && backend) {
                                backend.setInstallType("advanced")
                            }
                        }
                    }
                    
                    Label {
                        text: "    Load profile or import config"
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                    
                    Button {
                        text: "Next"
                        enabled: presetRadio.checked || customRadio.checked || advancedRadio.checked
                        Layout.alignment: Qt.AlignHCenter
                        onClicked: {
                            if (presetRadio.checked) {
                                if (backend) backend.goToPage(2)
                            } else if (customRadio.checked) {
                                if (backend) backend.goToPage(3)
                            } else if (advancedRadio.checked) {
                                if (backend) backend.goToPage(6)
                            }
                        }
                    }
                }
            }
            
            // Page 2: Presets
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 15
                    
                    Label {
                        text: "Select Preset"
                        font.pixelSize: 18
                        font.bold: true
                    }
                    
                    Label {
                        text: "System Presets:"
                        font.bold: true
                    }
                    
                    property string selectedPreset: ""
                    
                    Repeater {
                        model: backend ? backend.systemPresets : []
                        delegate: RadioButton {
                            text: modelData
                            Layout.fillWidth: true
                            onCheckedChanged: {
                                if (checked) {
                                    parent.parent.selectedPreset = modelData
                                    if (backend) {
                                        backend.setPreset(modelData)
                                    }
                                }
                            }
                        }
                    }
                    
                    Label {
                        text: "Device Presets:"
                        font.bold: true
                        Layout.topMargin: 10
                    }
                    
                    Repeater {
                        model: backend ? backend.devicePresets : []
                        delegate: RadioButton {
                            text: modelData
                            Layout.fillWidth: true
                            onCheckedChanged: {
                                if (checked) {
                                    parent.parent.parent.selectedPreset = modelData
                                    if (backend) {
                                        backend.setPreset(modelData)
                                    }
                                }
                            }
                        }
                    }
                    
                    RowLayout {
                        Button {
                            text: "Back"
                            onClicked: {
                                if (backend) backend.goToPage(1)
                            }
                        }
                        Button {
                            text: "Next"
                            enabled: parent.parent.selectedPreset !== ""
                            onClicked: {
                                if (backend && parent.parent.selectedPreset !== "") {
                                    backend.goToPage(7)  // Go to summary
                                }
                            }
                        }
                    }
                }
            }
            
            // Page 3: Custom Setup - System Type
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 15
                    
                    Label {
                        text: "Custom Setup - Step 1/3"
                        font.pixelSize: 18
                        font.bold: true
                    }
                    
                    Label {
                        text: "Select System Type:"
                        Layout.fillWidth: true
                    }
                    
                    property string selectedSystemType: ""
                    
                    Repeater {
                        model: backend ? backend.systemTypes : []
                        delegate: RadioButton {
                            text: modelData
                            Layout.fillWidth: true
                            onCheckedChanged: {
                                if (checked) {
                                    parent.parent.selectedSystemType = modelData.toLowerCase()
                                    if (backend) {
                                        backend.setSystemType(modelData.toLowerCase())
                                    }
                                }
                            }
                        }
                    }
                    
                    RowLayout {
                        Button {
                            text: "Back"
                            onClicked: {
                                if (backend) backend.goToPage(1)
                            }
                        }
                        Button {
                            text: "Next"
                            enabled: parent.parent.selectedSystemType !== ""
                            onClicked: {
                                // If desktop, go to desktop env page, else to features
                                if (backend && parent.parent.selectedSystemType === "desktop") {
                                    backend.goToPage(4)
                                } else if (backend && parent.parent.selectedSystemType !== "") {
                                    backend.goToPage(5)
                                }
                            }
                        }
                    }
                }
            }
            
            // Page 4: Custom Setup - Desktop Environment
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 15
                    
                    Label {
                        text: "Custom Setup - Step 2/3"
                        font.pixelSize: 18
                        font.bold: true
                    }
                    
                    Label {
                        text: "Select Desktop Environment:"
                        Layout.fillWidth: true
                    }
                    
                    Repeater {
                        model: backend ? backend.desktopEnvironments : []
                        delegate: RadioButton {
                            text: modelData
                            Layout.fillWidth: true
                            onCheckedChanged: {
                                if (checked && backend) {
                                    var de = modelData.toLowerCase()
                                    if (de === "plasma (kde)") de = "plasma"
                                    if (de === "none") de = ""
                                    backend.setDesktopEnv(de)
                                }
                            }
                        }
                    }
                    
                    RowLayout {
                        Button {
                            text: "Back"
                            onClicked: {
                                if (backend) backend.goToPage(3)
                            }
                        }
                        Button {
                            text: "Next"
                            onClicked: {
                                if (backend) backend.goToPage(5)
                            }
                        }
                    }
                }
            }
            
            // Page 5: Custom Setup - Features
            Item {
                ScrollView {
                    anchors.fill: parent
                    
                    ColumnLayout {
                        width: parent.width
                        spacing: 15
                        
                        Label {
                            text: "Custom Setup - Step 3/3"
                            font.pixelSize: 18
                            font.bold: true
                        }
                        
                        Label {
                            text: "Select Features (multiple selection):"
                            Layout.fillWidth: true
                        }
                        
                        Repeater {
                            model: backend ? Object.keys(backend.featureGroups) : []
                            delegate: GroupBox {
                                title: modelData
                                Layout.fillWidth: true
                                
                                ColumnLayout {
                                    anchors.fill: parent
                                    
                                    Repeater {
                                        model: backend ? backend.featureGroups[modelData] : []
                                        delegate: CheckBox {
                                            text: modelData
                                            Layout.fillWidth: true
                                            onCheckedChanged: {
                                                if (backend) {
                                                    // Map display names to internal names
                                                    var featureMap = {
                                                        "Web Development": "web-dev",
                                                        "Game Development": "game-dev",
                                                        "Python Development": "python-dev",
                                                        "System Development": "system-dev",
                                                        "Streaming": "streaming",
                                                        "Emulation": "emulation",
                                                        "Docker": "docker",
                                                        "Podman": "podman",
                                                        "Database": "database",
                                                        "Web Server": "web-server",
                                                        "Mail Server": "mail-server",
                                                        "QEMU/KVM": "qemu-vm",
                                                        "Virt Manager": "virt-manager"
                                                    }
                                                    var feature = featureMap[modelData] || modelData.toLowerCase().replace(/\s+/g, "-")
                                                    backend.toggleFeature(feature, checked)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        RowLayout {
                            Button {
                                text: "Back"
                                onClicked: {
                                    if (backend) {
                                        if (backend.systemType === "desktop") {
                                            backend.goToPage(4)
                                        } else {
                                            backend.goToPage(3)
                                        }
                                    }
                                }
                            }
                            Button {
                                text: "Next"
                                onClicked: {
                                    if (backend) backend.goToPage(7)  // Go to summary
                                }
                            }
                        }
                    }
                }
            }
            
            // Page 6: Advanced Options
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 15
                    
                    Label {
                        text: "Advanced Options"
                        font.pixelSize: 18
                        font.bold: true
                    }
                    
                    Button {
                        text: "📁 Load Profile from File"
                        Layout.fillWidth: true
                        onClicked: {
                            // TODO: Implement file dialog
                            statusLabel.text = "Load Profile from File - Not yet implemented"
                        }
                    }
                    
                    Button {
                        text: "📋 Show Available Profiles"
                        Layout.fillWidth: true
                        onClicked: {
                            // TODO: Implement profile browser
                            statusLabel.text = "Show Available Profiles - Not yet implemented"
                        }
                    }
                    
                    Button {
                        text: "🔄 Import from Existing Config"
                        Layout.fillWidth: true
                        onClicked: {
                            // TODO: Implement config import
                            statusLabel.text = "Import from Existing Config - Not yet implemented"
                        }
                    }
                    
                    RowLayout {
                        Button {
                            text: "Back"
                            onClicked: {
                                if (backend) backend.goToPage(1)
                            }
                        }
                        Button {
                            text: "Next"
                            onClicked: {
                                if (backend) backend.goToPage(7)  // Go to summary
                            }
                        }
                    }
                }
            }
            
            // Page 7: Summary
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 15
                    
                    Label {
                        text: "Configuration Summary"
                        font.pixelSize: 18
                        font.bold: true
                    }
                    
                    Label {
                        text: "Your NixOS Configuration:"
                        font.bold: true
                    }
                    
                    Label {
                        text: "System Type: " + (backend ? backend.systemType : "")
                        Layout.fillWidth: true
                    }
                    
                    Label {
                        text: "Desktop Environment: " + (backend ? (backend.desktopEnv || "None") : "")
                        Layout.fillWidth: true
                    }
                    
                    Label {
                        text: "Selected Features:"
                        font.bold: true
                        Layout.topMargin: 10
                    }
                    
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 200
                        
                        ListView {
                            model: backend ? backend.selectedFeatures : []
                            delegate: Label {
                                text: "• " + modelData
                            }
                        }
                    }
                    
                    RowLayout {
                        Button {
                            text: "Back"
                            onClicked: {
                                if (backend) {
                                    // Go back to appropriate page
                                    if (backend.installType === "presets") {
                                        backend.goToPage(2)
                                    } else if (backend.installType === "custom") {
                                        backend.goToPage(5)
                                    } else {
                                        backend.goToPage(6)
                                    }
                                }
                            }
                        }
                        Button {
                            text: "Install"
                            onClicked: {
                                if (backend) {
                                    backend.startSetup()
                                    backend.goToPage(8)  // Go to progress page
                                }
                            }
                        }
                    }
                }
            }
            
            // Page 8: Installation Progress
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 15
                    
                    Label {
                        text: "Installing NixOS Control Center"
                        font.pixelSize: 18
                        font.bold: true
                    }
                    
                    ProgressBar {
                        id: installProgress
                        Layout.fillWidth: true
                        value: backend ? backend.setupProgress / 100.0 : 0.0
                        indeterminate: backend && backend.setupRunning && backend.setupProgress === 0
                    }
                    
                    Label {
                        text: "Setting up configuration..."
                        Layout.fillWidth: true
                    }
                    
                    ColumnLayout {
                        Label {
                            text: "Current step:"
                            font.bold: true
                        }
                        
                        Label {
                            text: "• ✅ Hardware checks completed"
                        }
                        
                        Label {
                            text: backend && backend.setupRunning ? "• 🔄 Building NixOS configuration..." : "• ⏳ Waiting..."
                        }
                        
                        Label {
                            text: "This may take a few minutes..."
                        }
                    }
                }
                
                Connections {
                    target: backend
                    function onSetupProgressChanged(progress) {
                        installProgress.value = progress / 100.0
                    }
                    function onSetupRunningChanged(running) {
                        if (!running && backend.setupProgress === 100) {
                            statusLabel.text = "Installation completed!"
                        }
                    }
                }
            }
        }
    }
}
