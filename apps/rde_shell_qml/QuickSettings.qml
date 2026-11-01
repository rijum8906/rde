// QuickSettings.qml — Android-style pill quick settings (Wi-Fi, small toggles, sliders)
import QtQuick
import QtQuick.Controls
import M3Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: qsPanel
    property bool isOpen: false

    // ===== STATE =====
    property bool wifiEnabled: false
    property bool hasSeenState: false

    property bool bluetoothEnabled: false
    property bool dndEnabled: false
    property bool nightEnabled: false

    // There is no WWAN hardware on this machine, so airplane mode means every
    // radio (Wi-Fi + Bluetooth) is off.
    readonly property bool airplaneEnabled: hasSeenState && !wifiEnabled && !bluetoothEnabled

    property real volume: 0.5
    property real brightness: 0.7

    function refresh() {
        radioReader.running = true;
        bluetoothReader.running = true;
        nightReader.running = true;
        dndReader.running = true;
        volumeReader.running = true;
        brightnessReader.running = true;
    }

    function toggleWifi() {
        var next = !qsPanel.wifiEnabled;
        qsPanel.wifiEnabled = next;
        radioSetter.command = ["nmcli", "radio", "wifi", next ? "on" : "off"];
        radioSetter.running = true;
        settleTimer.restart();
    }

    function toggleBluetooth() {
        qsPanel.bluetoothEnabled = !qsPanel.bluetoothEnabled;
        bluetoothSetter.command = ["bluetoothctl", "power", qsPanel.bluetoothEnabled ? "on" : "off"];
        bluetoothSetter.running = true;
        bluetoothSettleTimer.restart();
    }

    // Plasma exposes no DBus API for Do Not Disturb on this build, so this
    // writes the same plasmanotifyrc key the notification applet uses.
    function toggleDnd() {
        qsPanel.dndEnabled = !qsPanel.dndEnabled;
        dndSetter.command = ["kwriteconfig6", "--file", "plasmanotifyrc", "--group", "Notifications", "--key", "DoNotDisturb", qsPanel.dndEnabled ? "true" : "false"];
        dndSetter.running = true;
    }

    // KWin's NightLight `enabled` property is read-only, so the tint is applied
    // through the preview API the Night Color settings module uses.
    function toggleNight() {
        qsPanel.nightEnabled = !qsPanel.nightEnabled;
        nightSetter.command = qsPanel.nightEnabled ? ["busctl", "--user", "call", "org.kde.KWin", "/org/kde/KWin/NightLight", "org.kde.KWin.NightLight", "preview", "u", "4500"] : ["busctl", "--user", "call", "org.kde.KWin", "/org/kde/KWin/NightLight", "org.kde.KWin.NightLight", "stopPreview"];
        nightSetter.running = true;
    }

    function toggleAirplane() {
        var next = !qsPanel.airplaneEnabled;
        airplaneSetter.command = ["sh", "-c", next ? "nmcli radio wifi off; bluetoothctl power off" : "nmcli radio wifi on; bluetoothctl power on"];
        airplaneSetter.running = true;
        settleTimer.restart();
        bluetoothSettleTimer.restart();
    }

    function smallActive(key) {
        switch (key) {
        case "wifi":
            return qsPanel.wifiEnabled;
        case "bluetooth":
            return qsPanel.bluetoothEnabled;
        case "dnd":
            return qsPanel.dndEnabled;
        case "night":
            return qsPanel.nightEnabled;
        case "airplane":
            return qsPanel.airplaneEnabled;
        }
        return false;
    }

    function toggleSmall(key) {
        switch (key) {
        case "wifi":
            qsPanel.toggleWifi();
            break;
        case "bluetooth":
            qsPanel.toggleBluetooth();
            break;
        case "dnd":
            qsPanel.dndEnabled = !qsPanel.dndEnabled;
            break;
        case "night":
            qsPanel.nightEnabled = !qsPanel.nightEnabled;
            break;
        case "airplane":
            qsPanel.airplaneEnabled = !qsPanel.airplaneEnabled;
            break;
        }
    }

    function applyVolume() {
        if (volumeSetter.running)
            return;
        volumeSetter.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", qsPanel.volume.toFixed(2)];
        volumeSetter.running = true;
    }

    function applyBrightness() {
        if (brightnessSetter.running)
            return;
        var pct = Math.round(qsPanel.brightness * 100);
        // KDE exposes brightness over kscreen-doctor; write access to
        // /sys/class/backlight is root-only, so sysfs is not an option here.
        brightnessSetter.command = ["sh", "-c", "kscreen-doctor -o 2>/dev/null | awk '/^Output:/{print $3; exit}' | xargs -r -I{} kscreen-doctor output.{}.brightness." + pct];
        brightnessSetter.running = true;
    }

    // Dismissal can also be triggered from outside the panel (backdrop click)
    function dismiss() {
        qsPanel.isOpen = false;
    }

    // Correct Quickshell anchoring syntax
    anchors {
        top: true
        right: true
    }

    // ===== GEOMETRY =====
    // The surface is taller than the card so the card can travel in from the top
    // edge and overshoot on the bounce without being clipped by the window.
    readonly property int cardWidth: 348
    readonly property int cardHeight: 234
    readonly property int slideDistance: 44
    readonly property int bounceRoom: 24

    margins {
        top: 48 - slideDistance
        right: 12
    }

    exclusiveZone: 0

    implicitWidth: cardWidth
    implicitHeight: cardHeight + slideDistance + bounceRoom
    color: "transparent"

    visible: true

    // Stop input when closed so it doesn't block clicks underneath it. The mask
    // tracks the card, so the transparent travel space above it stays
    // click-through and the top bar underneath keeps working.
    readonly property Region openMask: Region {
        x: 0
        y: panelContent.y
        width: qsPanel.cardWidth
        height: qsPanel.cardHeight
    }
    readonly property Region closedMask: Region {
        width: 0
        height: 0
    }
    mask: isOpen ? qsPanel.openMask : qsPanel.closedMask

    // Draw above the click-catcher backdrop (Top layer) and the bars, so a
    // click on the panel always reaches the panel, not the backdrop.
    WlrLayershell.layer: WlrLayer.Overlay

    // Hold the keyboard only while the panel is open, so Escape works no matter
    // which shell surface was clicked to open it. Released as soon as it closes.
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Shortcut {
        sequence: "Escape"
        enabled: qsPanel.isOpen
        context: Qt.WindowShortcut
        onActivated: qsPanel.isOpen = false
    }

    // ===== MATERIAL 3 DARK TOKENS =====
    readonly property color surface: "#F71C1A20"
    readonly property color board: "#14FFFFFF"
    readonly property color boardBorder: "#1FFFFFFF"
    readonly property color headerMuted: "#CAC4D0"
    readonly property color outline: "#8E8A84"
    readonly property color trackInactive: "#3A3632"

    // Active tiles are light capsules with dark content (as in the reference);
    // inactive tiles sit darker with light content.
    readonly property color tileOn: "#FBE0C3"
    readonly property color tileOnContent: "#201A16"
    readonly property color tileOff: "#2B2930"
    readonly property color tileOffContent: "#E6E0E9"
    readonly property color tileOffMuted: "#CAC4D0"

    // ===== BACKENDS =====
    // Wi-Fi radio: "enabled" / "disabled"
    Process {
        id: radioReader
        command: ["nmcli", "radio", "wifi"]
        stdout: SplitParser {
            onRead: line => {
                var v = line.trim();
                if (v.length === 0)
                    return;
                qsPanel.wifiEnabled = (v === "enabled");
                qsPanel.hasSeenState = true;
            }
        }
    }

    Process {
        id: radioSetter
        onExited: qsPanel.refresh()
    }

    // Let nmcli settle after a toggle before re-reading the state
    Timer {
        id: settleTimer
        interval: 700
        repeat: false
        onTriggered: qsPanel.refresh()
    }

    // Bluetooth: "Powered: yes" / "Powered: no"
    Process {
        id: bluetoothReader
        command: ["bluetoothctl", "show"]
        stdout: SplitParser {
            onRead: line => {
                var v = line.trim();
                if (v.startsWith("Powered:"))
                    qsPanel.bluetoothEnabled = (v.indexOf("yes") !== -1);
            }
        }
    }

    Process {
        id: bluetoothSetter
        onExited: bluetoothReader.running = true
    }

    Timer {
        id: bluetoothSettleTimer
        interval: 700
        repeat: false
        onTriggered: bluetoothReader.running = true
    }

    // Night light state: the current colour temperature KWin is applying.
    // Daylight is 6500K; anything clearly below that means it is tinted.
    Process {
        id: nightReader
        command: ["busctl", "--user", "get-property", "org.kde.KWin", "/org/kde/KWin/NightLight", "org.kde.KWin.NightLight", "currentTemperature"]
        stdout: SplitParser {
            onRead: line => {
                var parts = line.trim().split(" ");
                if (parts.length < 2)
                    return;
                var temp = parseFloat(parts[1]);
                if (!isNaN(temp))
                    qsPanel.nightEnabled = (temp > 0 && temp < 6000);
            }
        }
    }

    Process {
        id: nightSetter
        onExited: nightSettleTimer.restart()
    }

    // The temperature ramps, so wait before reading it back.
    Timer {
        id: nightSettleTimer
        interval: 900
        repeat: false
        onTriggered: nightReader.running = true
    }

    // Do Not Disturb: persisted in plasmanotifyrc.
    Process {
        id: dndReader
        command: ["kreadconfig6", "--file", "plasmanotifyrc", "--group", "Notifications", "--key", "DoNotDisturb", "--default", "false"]
        stdout: SplitParser {
            onRead: line => {
                var v = line.trim().toLowerCase();
                if (v.length > 0)
                    qsPanel.dndEnabled = (v === "true");
            }
        }
    }

    Process {
        id: dndSetter
        onExited: dndReader.running = true
    }

    // Airplane mode drives both radios in one shot.
    Process {
        id: airplaneSetter
    }

    // Volume: "Volume: 0.32"
    Process {
        id: volumeReader
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: line => {
                var v = line.trim();
                if (!v.startsWith("Volume:"))
                    return;
                var parts = v.split(" ");
                if (parts.length > 1) {
                    var parsed = parseFloat(parts[1]);
                    if (!isNaN(parsed))
                        qsPanel.volume = parsed;
                }
            }
        }
    }

    Process {
        id: volumeSetter
    }

    Timer {
        id: volumeDebounce
        interval: 90
        repeat: false
        onTriggered: qsPanel.applyVolume()
    }

    // Brightness: "Brightness control: supported, set to 25% and dimming to 100%"
    Process {
        id: brightnessReader
        command: ["sh", "-c", "p=$(kscreen-doctor -o 2>/dev/null | grep -m1 'Brightness control' | grep -oE '[0-9]+%' | head -1 | tr -d '%'); echo ${p:-0}"]
        stdout: SplitParser {
            onRead: line => {
                var pct = parseFloat(line.trim());
                if (!isNaN(pct) && pct > 0)
                    qsPanel.brightness = pct / 100;
            }
        }
    }

    Process {
        id: brightnessSetter
    }

    Timer {
        id: brightnessDebounce
        interval: 90
        repeat: false
        onTriggered: qsPanel.applyBrightness()
    }

    // Poll only while the panel is on screen
    Timer {
        id: poller
        interval: 5000
        repeat: true
        running: qsPanel.isOpen
        triggeredOnStart: true
        onTriggered: qsPanel.refresh()
    }

    onIsOpenChanged: if (isOpen)
        refresh()

    Rectangle {
        id: panelContent
        width: qsPanel.cardWidth
        height: qsPanel.cardHeight
        x: 0
        radius: 32
        color: qsPanel.surface
        border.width: 1
        border.color: "#1FFFFFFF"

        // Drops in from above the top bar and springs past its resting spot.
        y: qsPanel.isOpen ? qsPanel.slideDistance : 0
        opacity: qsPanel.isOpen ? 1.0 : 0.0
        visible: qsPanel.isOpen || opacity > 0.0

        Behavior on y {
            NumberAnimation {
                duration: qsPanel.isOpen ? 460 : 200
                easing.type: qsPanel.isOpen ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 2.0
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: qsPanel.isOpen ? 160 : 140
                easing.type: Easing.OutCubic
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 0

            // ===== DRAG HANDLE =====
            Item {
                width: parent.width
                height: 4

                Rectangle {
                    anchors.centerIn: parent
                    width: 32
                    height: 4
                    radius: 2
                    color: "#4A463F"
                }
            }

            Item {
                width: parent.width
                height: 10
            }

            // ===== HEADER =====
            Item {
                width: parent.width
                height: 32

                Item {
                    id: avatar
                    width: 32
                    height: 32
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    MaterialShape {
                        anchors.fill: parent
                        shape: MaterialShape.Circle
                        color: qsPanel.tileOn
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "R"
                        color: qsPanel.tileOnContent
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                }

                Column {
                    anchors.left: avatar.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: "Rijum"
                        color: qsPanel.tileOffContent
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }
                    Text {
                        text: "RDE Desktop"
                        color: qsPanel.headerMuted
                        font.pixelSize: 11
                    }
                }
            }

            Item {
                width: parent.width
                height: 14
            }

            // ===== TILE BOARD =====
            Rectangle {
                id: board
                width: parent.width
                height: 76
                radius: 32
                color: qsPanel.board
                border.width: 1
                border.color: qsPanel.boardBorder

                // ===== ICON TOGGLES =====
                Item {
                    id: smallRow
                    x: 12
                    y: 12
                    width: parent.width - 24
                    height: 52

                    Repeater {
                        id: smallRepeater
                        model: [
                            {
                                key: "wifi",
                                icon: "󰖩",
                                iconOff: "󰖪"
                            },
                            {
                                key: "bluetooth",
                                icon: "󰂯",
                                iconOff: "󰂲"
                            },
                            {
                                key: "dnd",
                                icon: "󰂛",
                                iconOff: "󰂛"
                            },
                            {
                                key: "night",
                                icon: "󰖔",
                                iconOff: "󰖔"
                            },
                            {
                                key: "airplane",
                                icon: "󰀝",
                                iconOff: "󰀝"
                            }
                        ]

                        delegate: Item {
                            id: smallButton
                            required property var modelData
                            required property int index

                            property bool active: qsPanel.smallActive(modelData.key)

                            x: index * ((smallRow.width - 52) / Math.max(1, smallRepeater.count - 1))
                            width: 52
                            height: 52
                            scale: smallMouse.pressed ? 0.94 : 1.0

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }

                            // Each tile morphs between an M3 circle and a M3 cookie
                            // shape as it toggles.
                            MaterialShape {
                                anchors.fill: parent
                                shape: smallButton.active ? MaterialShape.Cookie4Sided : MaterialShape.Circle
                                color: smallButton.active ? qsPanel.tileOn : qsPanel.tileOff
                                animationDuration: 420
                                animationEasing.type: Easing.OutBack
                            }

                            MaterialShape {
                                anchors.fill: parent
                                shape: smallButton.active ? MaterialShape.Cookie4Sided : MaterialShape.Circle
                                color: smallButton.active ? "#000000" : "#FFFFFF"
                                opacity: smallMouse.containsMouse ? 0.06 : 0.0
                                animationDuration: 420
                                animationEasing.type: Easing.OutBack

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 120
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: smallButton.active ? smallButton.modelData.icon : smallButton.modelData.iconOff
                                color: smallButton.active ? qsPanel.tileOnContent : qsPanel.tileOffMuted
                                font.pixelSize: 24
                            }

                            MouseArea {
                                id: smallMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: qsPanel.toggleSmall(smallButton.modelData.key)
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 14
            }

            // ===== VOLUME =====
            Item {
                width: parent.width
                height: 40

                Text {
                    id: volumeIcon
                    text: "󰕾"
                    color: qsPanel.headerMuted
                    font.pixelSize: 20
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }

                Slider {
                    id: volumeSlider
                    anchors.left: volumeIcon.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 40
                    from: 0
                    to: 1
                    stepSize: 0.01
                    value: qsPanel.volume

                    onMoved: {
                        qsPanel.volume = value;
                        volumeDebounce.restart();
                    }

                    background: Rectangle {
                        x: parent.leftPadding
                        y: parent.topPadding + parent.availableHeight / 2 - height / 2
                        width: parent.availableWidth
                        height: 8
                        radius: 4
                        color: qsPanel.trackInactive

                        Rectangle {
                            width: parent.visualPosition * parent.width
                            height: parent.height
                            radius: 4
                            color: qsPanel.tileOn
                        }
                    }

                    handle: Rectangle {
                        x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                        y: parent.topPadding + parent.availableHeight / 2 - height / 2
                        width: 20
                        height: 20
                        radius: 10
                        color: qsPanel.tileOn
                    }
                }
            }

            Item {
                width: parent.width
                height: 4
            }

            // ===== BRIGHTNESS =====
            Item {
                width: parent.width
                height: 40

                Text {
                    id: brightnessIcon
                    text: "󰃟"
                    color: qsPanel.headerMuted
                    font.pixelSize: 20
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }

                Slider {
                    id: brightnessSlider
                    anchors.left: brightnessIcon.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 40
                    from: 0.05
                    to: 1
                    stepSize: 0.01
                    value: qsPanel.brightness

                    onMoved: {
                        qsPanel.brightness = value;
                        brightnessDebounce.restart();
                    }

                    background: Rectangle {
                        x: parent.leftPadding
                        y: parent.topPadding + parent.availableHeight / 2 - height / 2
                        width: parent.availableWidth
                        height: 8
                        radius: 4
                        color: qsPanel.trackInactive

                        Rectangle {
                            width: parent.visualPosition * parent.width
                            height: parent.height
                            radius: 4
                            color: qsPanel.tileOn
                        }
                    }

                    handle: Rectangle {
                        x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                        y: parent.topPadding + parent.availableHeight / 2 - height / 2
                        width: 20
                        height: 20
                        radius: 10
                        color: qsPanel.tileOn
                    }
                }
            }
        }
    }
}
