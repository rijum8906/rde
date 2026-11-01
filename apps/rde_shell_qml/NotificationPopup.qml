// NotificationPopup.qml
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: popup
    property bool isOpen: false
    
    anchors {
        top: true
        right: true
    }
    margins.top: 50
    margins.right: 12
    exclusiveZone: 0
    implicitWidth: 350
    implicitHeight: 100
    color: "transparent"
    visible: isOpen

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: "#F22A2A2E"
        border.width: 1
        border.color: "#40FFFFFF"

        Row {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Rectangle {
                width: 36; height: 36; radius: 12
                anchors.verticalCenter: parent.verticalCenter
                color: "#FBE0C3"
                Text {
                    anchors.centerIn: parent
                    text: "!"
                    color: "#201A16"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }
            }

            Column {
                width: parent.width - 36 - 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text {
                    text: qsTr("Notification")
                    color: "#F5F1F8"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    text: qsTr("This is a placeholder notification. Click the bell to hide it.")
                    color: "#C9C3CF"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
