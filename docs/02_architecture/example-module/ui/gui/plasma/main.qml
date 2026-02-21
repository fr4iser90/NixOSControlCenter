// KDE Plasma GUI (QML)
// Purpose: Desktop GUI für KDE Plasma

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ApplicationWindow {
    id: window
    title: "Example Module"
    width: 800
    height: 600
    visible: true
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        
        Text {
            text: "Example Module"
            font.pixelSize: 24
            font.bold: true
        }
        
        Button {
            text: "List Items"
            onClicked: {
                // Call CLI command or API
                console.log("List items clicked")
            }
        }
        
        Button {
            text: "Add Item"
            onClicked: {
                // Call CLI command or API
                console.log("Add item clicked")
            }
        }
    }
}
