# RDE Theme Manager Architecture (`rde-theme`)

The **RDE Theme Manager** (`rde-theme`) is a decoupled microservice responsible for centralizing, generating, and synchronizing visual appearance settings across the Riju Desktop Environment (RDE).

It bridges modern **Material 3 (M3)** design principles with Linux desktop toolkits (GTK 3, GTK 4, Qt 5, Qt 6) and native RDE shell components.

---

## 🎯 Architecture Goals

1. **Unified Source of Truth**: Manage colors, fonts, icons, cursor themes, and dark/light modes from a single central engine.
2. **Material 3 Design System**: Implement dynamic color extraction, tonal palettes, and M3 color roles.
3. **Cross-Toolkit Synchronization**: Apply generated theme palettes seamlessly to GTK 3/4, Qt 5/6, and native RDE apps without requiring system restarts.
4. **XDG Standard Compliance**: Expose standard Freedesktop / XDG settings interfaces (`org.freedesktop.portal.Settings`) alongside RDE's D-Bus contracts (`org.rde.Theme`).

---

## 🎨 Material 3 Design System Engine

`rde-theme` uses Google's Material 3 design system to construct harmonious color schemes from seed colors (or wallpaper images).

### 1. Color Role Mapping Schema

The engine maintains a strict, strongly-typed Material 3 color role system:

| M3 Color Role | Description / Application |
| :--- | :--- |
| **`Primary`** | High-emphasis fill for primary buttons, active tabs, and key UI elements. |
| **`OnPrimary`** | Foreground text/icon color drawn on top of `Primary`. |
| **`PrimaryContainer`** | Standout background container fill for featured cards or selected list items. |
| **`OnPrimaryContainer`** | Text/icon color drawn on top of `PrimaryContainer`. |
| **`Secondary`** | Less prominent UI elements, toggle buttons, and secondary badges. |
| **`OnSecondary`** | Foreground text/icon color drawn on top of `Secondary`. |
| **`SecondaryContainer`** | Soft container background for secondary controls and chips. |
| **`OnSecondaryContainer`** | Text/icon color drawn on top of `SecondaryContainer`. |
| **`Tertiary`** | Accent color for subtle highlights, notifications, or custom indicators. |
| **`OnTertiary`** | Foreground text/icon color drawn on top of `Tertiary`. |
| **`TertiaryContainer`** | Soft background fill for tertiary containers. |
| **`OnTertiaryContainer`** | Text/icon color drawn on top of `TertiaryContainer`. |
| **`Error`** | Destructive actions, warnings, and error alerts. |
| **`OnError`** | Text/icon color drawn on top of `Error`. |
| **`ErrorContainer`** | Background fill for error banners or alert dialogs. |
| **`OnErrorContainer`** | Text/icon color drawn on top of `ErrorContainer`. |
| **`Surface`** | Standard background surface color for application windows and panels. |
| **`OnSurface`** | Primary text and high-emphasis icons drawn on top of `Surface`. |
| **`SurfaceVariant`** | Secondary surface variant for cards, dividers, and sidebars. |
| **`OnSurfaceVariant`** | Medium-emphasis text and icons drawn on top of `SurfaceVariant`. |
| **`Outline`** | Borders, outlines, and structural divider lines. |
| **`OutlineVariant`** | Subtle border tint for low-contrast card outlines. |
| **`InverseSurface`** | High-contrast surface fill for snackbars and floating toasts. |
| **`InverseOnSurface`** | Text color drawn on top of `InverseSurface`. |
| **`InversePrimary`** | Action button color used inside `InverseSurface` components. |
| **`Scrim`** | Semi-transparent overlay mask for modal dialog backdrops. |
| **`Shadow`** | Drop-shadow tint color for elevation effects. |

### 2. Tonal Palette & Scheme Generation

- **Dynamic Color Extraction**: Generates dynamic palettes from user seed hex colors or dominant wallpaper colors.
- **Light / Dark Mode Variants**: Automatically derives both Light and Dark M3 color schemes from the active tonal palette, adjusting contrast ratios according to Web Content Accessibility Guidelines (WCAG 2.1 AA standard).

---

## 🛠️ Toolkit Integration Architecture

### 1. GTK Theme Management Engine (GTK 3 & GTK 4)

- **`settings.ini` Configuration**: Writes GTK configuration options to `~/.config/gtk-3.0/settings.ini` and `~/.config/gtk-4.0/settings.ini`:
  - `gtk-theme-name`
  - `gtk-icon-theme-name`
  - `gtk-cursor-theme-name`
  - `gtk-font-name`
  - `gtk-application-prefer-dark-theme` (0 = Light, 1 = Dark)
- **Dynamic CSS Injection (`gtk.css`)**: Generates custom CSS overrides containing `@define-color` definitions mapped to M3 color roles in `~/.config/gtk-3.0/gtk.css` and `~/.config/gtk-4.0/gtk.css`.
- **Portal & xsettingsd Synchronization**: Notifies `xsettingsd` or emits `org.freedesktop.portal.Settings` signals to ensure running GTK applications reload theme colors instantly without restart.

### 2. Qt Theme Management Engine (Qt 5 & Qt 6)

- **Qt Environment Integration**: Supports standard Qt style engines (`qt5ct`, `qt6ct`, and `kvantum`).
- **KConfig / KDE Globals Generation**: Writes M3 color schemes to `~/.config/kdeglobals` and `~/.config/qt5ct/colors/rde_m3.conf` so Qt 5 and Qt 6 applications render matching colors.
- **Palette Mapping**: Maps M3 roles to Qt color roles (`WindowText`, `Button`, `Light`, `Midlight`, `Dark`, `Mid`, `Text`, `BrightText`, `ButtonText`, `Base`, `Window`, `Shadow`, `Highlight`, `HighlightedText`, `Link`).

---

## 🔤 Typography & Font Management Engine

`rde-theme` controls system-wide typography settings and ensures consistent font rendering parameters across desktop components.

### 1. Font Classification Schema

- **Interface Font**: Primary font family used for window titles, menus, buttons, and desktop widgets (e.g., `Inter`, `Roboto`, or `Cantarell`).
- **Monospace Font**: Fixed-width font for terminals, code editors, and technical logs (e.g., `JetBrains Mono`, `Fira Code`, or `Hack`).
- **Document Font**: Reading font used for text documents and desktop viewers (e.g., `Roboto`, `Noto Serif`).

### 2. Typography Scale & Properties

- **Font Sizes**: Configurable baseline points (e.g. Interface: 10pt, Monospace: 11pt, Document: 11pt).
- **Subpixel Antialiasing & Hinting**:
  - `hinting`: `hintnone`, `hintslight`, `hintmedium`, `hintfull`.
  - `subpixel_order`: `none`, `rgb`, `bgr`, `vrgb`, `vbgr`.
  - `lcdfilter`: `lcdnone`, `lcddefault`, `lcdlight`.

---

## ⚡ System Event Flow & D-Bus Contracts

1. **User Request / Configuration Change**:
   - `rde-cli` or desktop control panel calls `org.rde.Theme.SetTheme(...)` or `org.rde.Theme.SetColorSeed(...)`.
2. **Palette Computation**:
   - `rde-theme` backend calculates the 27 M3 color roles and verifies contrast ratios.
3. **Toolkit File Generation**:
   - `rde-theme` writes updated GTK (`gtk.css`/`settings.ini`), Qt (`kdeglobals`/`qt5ct`), and Fontconfig files.
4. **Signal Dispatch**:
   - Emits `ThemeChanged` and `ColorPaletteChanged` signals over `org.rde.Theme` session D-Bus.
   - Updates Freedesktop Portal settings (`color-scheme` key: `0` = No preference, `1` = Prefer dark, `2` = Prefer light).
5. **Supervisor Status**:
   - Responds to `rde-daemon` IPC `HealthCheck` probes.
