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
| **`Background`** | Legacy background role kept for toolkits that still request it. |
| **`OnBackground`** | Legibility color for `Background`. |
| **`Surface`** | Standard background surface color for application windows and panels. |
| **`SurfaceDim`** | Dimmed surface for large dark areas in a light scheme. |
| **`SurfaceBright`** | Brightened surface for large light areas in a dark scheme. |
| **`OnSurface`** | Primary text and high-emphasis icons drawn on top of `Surface`. |
| **`SurfaceVariant`** | Secondary surface variant for cards, dividers, and sidebars. |
| **`OnSurfaceVariant`** | Medium-emphasis text and icons drawn on top of `SurfaceVariant`. |
| **`SurfaceContainerLowest`** | Lowest elevation container for subtle layering. |
| **`SurfaceContainerLow`** | Low elevation container for cards and lists. |
| **`SurfaceContainer`** | Default container for panels and sidebars. |
| **`SurfaceContainerHigh`** | High elevation container for sheets and menus. |
| **`SurfaceContainerHighest`** | Highest elevation container for dialogs and popovers. |
| **`SurfaceTint`** | Tint applied to elevated surfaces to signal brand color. |
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
- **Role Exposure**: Palettes are published as a stable `role_name → #RRGGBB` map (37 roles), so consumers never depend on Rust struct layout.

---

## 🗂️ Theme Database

All state lives in an XDG data directory, defaulting to `~/.local/share/rde/rde-theme/`:

```
$XDG_DATA_HOME/rde/rde-theme/
├── themes.toml                 registry: active theme, color scheme, installed list
└── themes/<name>/theme.toml    manifest: source color and theme metadata
```

- **Registry (`themes.toml`)**: session state only. It stores `schema_version`, `current_theme`, `color_scheme`, and `installed`. It never duplicates palette values, so a source color change cannot desynchronize colors from the theme definition.
- **Manifest (`themes/<name>/theme.toml`)**: authoritative definition of a theme (`name`, `display_name`, `description`, `author`, `license`, `version`, `source_color`). The built-in `default` theme is seeded when the database is empty.
- **Atomic persistence**: every write goes to a sibling temporary file and is renamed into place, so a crash cannot leave a truncated document.
- **Self-healing startup**: the installed list is reconciled with the manifests on disk (missing entries dropped, external manifests adopted), and an unparsable registry is moved to `themes.toml.invalid` and rebuilt. Theme directories with invalid names or manifests are skipped with a warning instead of preventing the service from starting.
- **Identifier safety**: theme names are validated (ASCII alphanumerics, `-`, `_`, `.`, leading alphanumeric, max 64 characters) before they are ever used as a path component.
- **Invariants**: the active theme is always installed and cannot be deleted; the active theme always resolves to a palette.

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
   - `rde-cli` or a desktop control panel calls `org.rde.Theme.SetTheme(...)`, `CreateTheme(name, source_color)`, `SetSourceColor(...)`, or writes the `ColorScheme` property.
2. **Validation and Persistence**:
   - The store validates the identifier and source color, then writes the affected manifest and/or registry atomically. Failed writes roll the in-memory state back.
3. **Palette Computation**:
   - The backend expands the theme's source color into the 37 M3 color roles for the requested light/dark scheme. Palettes are derived on demand and never persisted.
4. **Signal Dispatch**:
   - Emits `ThemeChanged`, `ColorSchemeChanged`, `PaletteChanged`, or `InstalledThemesChanged` over the `org.rde.Theme` session D-Bus interface, plus the standard `PropertiesChanged` signal for mutated properties.
5. **Toolkit Synchronization** (planned):
   - Writes updated GTK (`gtk.css`/`settings.ini`), Qt (`kdeglobals`/`qt5ct`), and Fontconfig files, and updates Freedesktop Portal settings (`color-scheme` key).
6. **Supervisor Status**:
   - Responds to `rde-daemon` IPC `HealthCheck` probes.
