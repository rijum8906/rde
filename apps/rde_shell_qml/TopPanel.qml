// TopPanel.qml
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland

PanelWindow {
    id: panel

    signal quickSettingsToggled
    property bool quickSettingsOpen: false

    readonly property color accent: "#FBE0C3"
    readonly property color foreground: "#E6E0E9"
    readonly property color surfaceContainer: "#B8141218"
    readonly property color surfaceContainerHover: "#26FFFFFF"
    readonly property color outline: "#26FFFFFF"

    anchors {
        top: true
        left: true
        right: true
    }
    exclusiveZone: 42
    implicitHeight: 42
    color: "transparent"

    readonly property var activePlayer: Mpris.players.length > 0 ? Mpris.players[0] : null
    readonly property bool hasMedia: activePlayer !== null && activePlayer.trackTitle !== ""
    readonly property bool isPlaying: activePlayer ? activePlayer.isPlaying : false
    readonly property string trackName: activePlayer ? activePlayer.trackTitle : ""
    readonly property string artistName: activePlayer ? activePlayer.trackArtist : ""

    // ===== CENTER: Dynamic Island =====
    Rectangle {
        anchors.centerIn: parent
        height: 32
        radius: 16
        color: panel.surfaceContainer
        border.width: 1
        border.color: panel.outline
        width: panel.hasMedia ? islandRow.implicitWidth + 24 : 0
        opacity: panel.hasMedia ? 1.0 : 0.0
        visible: width > 0

        Behavior on width {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }

        Row {
            id: islandRow
            anchors.centerIn: parent
            spacing: 10

            Rectangle {
                width: 20
                height: 20
                radius: 10
                color: "#33FBE0C3"
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    text: panel.isPlaying ? "󰏤" : "󰐊"
                    color: panel.accent
                    font.pixelSize: 12
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (panel.activePlayer)
                        panel.activePlayer.togglePlaying()
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: -2
                Text {
                    text: panel.trackName
                    color: panel.foreground
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 150)
                }
                Text {
                    text: panel.artistName
                    color: "#CAC4D0"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 150)
                }
            }
        }
    }

    // ===== RIGHT: System Tray =====
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: trayRow.implicitWidth + 16
        height: 30
        radius: 15
        color: panel.surfaceContainer
        border.width: 1
        border.color: panel.outline

        Row {
            id: trayRow
            anchors.centerIn: parent
            spacing: 4

            // Wi-Fi
            Rectangle {
                width: 28
                height: 28
                radius: 8
                color: wifiMouse.containsMouse ? panel.surfaceContainerHover : "transparent"
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: "󰖩"
                    color: panel.foreground
                    font.pixelSize: 16
                }
                MouseArea {
                    id: wifiMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                }
            }

            // Bluetooth
            Rectangle {
                width: 28
                height: 28
                radius: 8
                color: btMouse.containsMouse ? panel.surfaceContainerHover : "transparent"
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: "󰂯"
                    color: panel.foreground
                    font.pixelSize: 16
                }
                MouseArea {
                    id: btMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                }
            }

            Rectangle {
                width: 1
                height: 14
                color: panel.outline
                anchors.verticalCenter: parent.verticalCenter
            }

            // Quick Settings
            Rectangle {
                width: 28
                height: 28
                radius: 8
                color: panel.quickSettingsOpen ? "#33FBE0C3" : (qsMouse.containsMouse ? panel.surfaceContainerHover : "transparent")
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: "󰒓"
                    color: panel.quickSettingsOpen ? panel.accent : panel.foreground
                    font.pixelSize: 16
                }
                MouseArea {
                    id: qsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.quickSettingsToggled()
                }
            }
        }
    }
}
