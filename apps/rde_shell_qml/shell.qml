// shell.qml
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    // ===== CLICK OUTSIDE TO DISMISS =====
    // Fullscreen transparent surface that catches clicks which miss the open
    // panel. Declared before the other windows so it stacks below them: the
    // panel, top bar and dock keep receiving their own clicks.
    PanelWindow {
        id: backdrop
        anchors {
            top: true
            right: true
            bottom: true
            left: true
        }
        exclusiveZone: 0
        color: "transparent"
        visible: quickSettingsPopup.isOpen

        MouseArea {
            anchors.fill: parent
            onClicked: quickSettingsPopup.dismiss()
        }
    }

    TopPanel {
        id: topPanel
        quickSettingsOpen: quickSettingsPopup.isOpen
        onQuickSettingsToggled: {
            quickSettingsPopup.isOpen = !quickSettingsPopup.isOpen
        }
    }

    QuickSettings {
        id: quickSettingsPopup
    }

    BottomDock {
        id: bottomDock
    }
}
