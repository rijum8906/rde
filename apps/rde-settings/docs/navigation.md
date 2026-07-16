# Navigation

This file contains all the nvaigation links used in the app. And the information regarding the navigation links.

# Link Tree

```text
📱 RDE Settings
│
├── 📊 Dashboard
│   ├── Quick Toggles [Dark Mode, Wi-Fi, Bluetooth, DND]
│   ├── System Status [Battery %, RAM Util, Storage Util]
│   └── Quick Sliders [Master Volume, Brightness]
│
├── 🌐 Connectivity
│   ├── Wi-Fi [Toggle, AP List, Known Networks]
│   ├── Bluetooth [Toggle, Discoverable, Device Pair/List]
│   └── Network Proxy [Toggle, Type (HTTP/SOCKS), Host, Port]
│
├── 🎨 Personalization
│   ├── Theme & Styling [Mode (L/D/A), Palette Accent, Theme Pack (Dracula/Nord/Default)]
│   ├── Wallpaper [Preview, Source File/Folder, Fit Mode, Slideshow Interval]
│   ├── Typography [System Font, Mono Font, Size (8-24pt), Subpixel Antialiasing]
│   └── Interface Assets [Icon Pack, Cursor Theme, Scale Factor (100-200%)]
│
├── ⌨️ Hardware & Inputs
│   ├── Display [Resolution, Refresh Rate, Layout (Extend/Mirror), Night Light Temp]
│   ├── Audio IO [Output/Input Select, Volume Sliders, Noise Reduction, EQ Toggle]
│   ├── Keyboard [Layout/Variant, Repeat Delay/Rate, Boot NumLock]
│   ├── Pointer [Mouse Speed, Acceleration Toggle, Natural Scroll (Mouse/Touchpad)]
│   └── Window Manager Bindings [Global Keybindings List, Add Custom Shortcut]
│
├── 🔋 Power & Performance
│   ├── Battery Health [Status, Time Remaining, Panel Indicator Toggle]
│   ├── Sleep States [Dim Display Delay, Suspend Delay, Display Off Delay]
│   └── Hardware Triggers [Lid Close Action, Power Button Action, Low Battery Action]
│
├── 🔒 Security & Accounts
│   ├── Lock Screen [Toggle, Delay Timer, Auth Background, Notification Privacy]
│   ├── User Profile [Session Username, Avatar, Password Crypt Settings]
│   └── System Privacy [Clipboard History Toggle, Recent Apps/Files Log, Data Telemetry]
│
└── 🛠️ Core System (Advanced)
    ├── About RDE [Kernel/OS Version, Architecture, Update Checker, Log Viewer]
    ├── Environment [Hostname, Kernel Parameters, Profile Env Variables]
    ├── Daemons [Systemd/D-Bus Services List, Status Tracker, Process Lifecycle Control]
    └── Engine Overrides [Compositor Toggle, Window Manager Switcher, Animation Speed]
```

# Development

If you need to add a new navigation link, add it to the `core/navigation/router.dart` file.
