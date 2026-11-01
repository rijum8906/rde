// BottomDock.qml — floating, centered dock.
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: dock

    readonly property color accent: "#FBE0C3"
    readonly property color foreground: "#E6E0E9"
    readonly property color surfaceContainer: "#E61D1B22"
    readonly property color outline: "#33FFFFFF"
    readonly property int itemSize: 44

    anchors {
        bottom: true
        left: true
        right: true
    }
    margins.bottom: 10
    exclusiveZone: 0
    implicitHeight: 56
    color: "transparent"

    // The mask keeps only the dock pill clickable
    mask: Region {
        x: (dock.width - pill.width) / 2
        y: 0
        width: pill.width
        height: pill.height
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: dockRow.implicitWidth + 20
        height: 56
        radius: 20
        color: dock.surfaceContainer
        border.width: 1
        border.color: dock.outline

        Row {
            id: dockRow
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: [
                    {
                        name: "Terminal",
                        glyph: ">_",
                        exec: "foot"
                    },
                    {
                        name: "Browser",
                        glyph: "◎",
                        exec: "firefox"
                    },
                    {
                        name: "Files",
                        glyph: "▤",
                        exec: "nautilus"
                    },
                    {
                        name: "Settings",
                        glyph: "⚙",
                        exec: "gnome-control-center"
                    }
                ]

                delegate: Item {
                    id: dockItem
                    required property var modelData
                    width: dock.itemSize
                    height: dock.itemSize + 4

                    Process {
                        id: launcher
                        command: ["sh", "-c", modelData.exec + " &"]
                    }

                    RoundButton {
                        id: button
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: dock.itemSize
                        height: dock.itemSize
                        padding: 0
                        text: dockItem.modelData.glyph
                        hoverEnabled: true

                        onClicked: launcher.running = true

                        background: Rectangle {
                            radius: 15
                            color: button.down ? "#4DFBE0C3" : (button.hovered ? "#33FBE0C3" : "#1AFFFFFF")
                            border.width: 1
                            border.color: button.hovered ? "#66FBE0C3" : "#1FFFFFFF"
                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                        }

                        contentItem: Text {
                            text: button.text
                            color: button.hovered ? dock.accent : dock.foreground
                            font.pixelSize: 20
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        scale: button.hovered ? 1.06 : 1.0
                        Behavior on scale {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Rectangle {
                        width: 4
                        height: 4
                        radius: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        color: dock.accent
                        opacity: button.hovered ? 1.0 : 0.6
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }
                        }
                    }
                }
            }
        }
    }
}
