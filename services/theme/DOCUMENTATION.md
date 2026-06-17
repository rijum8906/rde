# rde-theme Documentation

This document provides a detailed technical reference for the `rde-theme` D-Bus service, including all properties, methods, and data structures.

## 📡 D-Bus Interface Overview

- **Service Name**: `org.rde.Theme`
- **Object Path**: `/org/rde/Theme`
- **Interface**: `org.rde.Theme`

---

## 🛠 Data Structures

### `Theme` (Struct)
The primary structure representing a complete theme.

| Field | Type | Description |
| :--- | :--- | :--- |
| `name` | `String` | The unique name of the theme. |
| `author` | `String` | The creator of the theme. |
| `version` | `String` | Version string (e.g., "1.0.0"). |
| `mode` | `ThemeMode` | The mode this specific object represents. |
| `colors` | `ThemeColors` | Color palette definition. |
| `typography` | `ThemeTypography` | Font and text style definitions. |
| `spacing` | `ThemeSizing` | Spacing and margin definitions. |
| `radius` | `ThemeSizing` | Corner radius definitions. |

### `ThemeMode` (Enum)
Supported theme modes.
- `Light`: Standard light appearance.
- `Dark`: Dark/Night appearance.

### `ThemeColors` (Struct)
Contains hexadecimal color strings for various UI elements. All fields are of type `String`.

| Category | Fields |
| :--- | :--- |
| **Primary** | `primary`, `on_primary`, `primary_container`, `on_primary_container` |
| **Secondary** | `secondary`, `on_secondary`, `secondary_container`, `on_secondary_container` |
| **Tertiary** | `tertiary`, `on_tertiary`, `tertiary_container`, `on_tertiary_container` |
| **Error** | `error`, `on_error`, `error_container`, `on_error_container` |
| **Surface** | `surface`, `on_surface`, `surface_variant`, `on_surface_variant` |
| **Background** | `background`, `on_background` |
| **Outline** | `outline`, `outline_variant` |
| **Surface Tints** | `surface_tint`, `scrim` |
| **Inverse** | `inverse_surface`, `inverse_on_surface`, `inverse_primary` |
| **Shadow** | `shadow` |
| **Surface Container** | `surface_container`, `surface_container_low`, `surface_container_high`, `surface_container_highest` |

### `ThemeTypography` (Struct)
Defines text styling parameters. All fields are of type `String`.

| Category | Fields |
| :--- | :--- |
| **Font Families** | `family`, `family_mono` |
| **Sizes** | `size_xs`, `size_sm`, `size_md`, `size_lg`, `size_xl` |
| **Weights** | `weight_light`, `weight_regular`, `weight_medium`, `weight_bold` |
| **Other** | `line_height`, `letter_spacing` |

### `ThemeSizing` (Struct)
A generic sizing structure used for spacing and radius. All fields are of type `String`.

| Field | Description |
| :--- | :--- |
| `xxs` | Double Extra Small |
| `xs` | Extra Small |
| `sm` | Small |
| `md` | Medium |
| `lg` | Large |
| `xl` | Extra Large |
| `xxl` | Double Extra Large |

---

## 🏠 Properties

### `mode`
- **Type**: `String`
- **Access**: Read/Write
- **Description**: Gets or sets the current theme mode.
- **Values**: `"light"`, `"dark"`.
- **Note**: Setting this will attempt to find the corresponding mode for the currently active theme.

### `current_theme`
- **Type**: `Theme` (Struct)
- **Access**: Read/Write
- **Description**: Gets the current active theme object or sets the active theme by its name.
- **Setter Argument**: `String` (The name of the theme to switch to).

---

## ⚙️ Methods

### `create_theme`
Registers a new theme in the system storage.
- **Arguments**:
  - `theme`: `Theme` (The theme object to create).
- **Returns**: `void`
- **Errors**: `InvalidArgs` if the theme already exists.

### `list_themes`
Retrieves a list of all registered themes.
- **Arguments**: None.
- **Returns**: `HashSet<String>` (A set of theme keys in the format `name:mode`).

### `refresh_themes_list`
Force reloads the themes list from the disk storage.
- **Arguments**: None.
- **Returns**: `void`

### `set_accent`
(Work in Progress) Sets the system-wide accent color.
- **Arguments**:
  - `color`: `String` (Hex color code).
- **Returns**: `void`
- **Errors**: Currently returns `Failed: Not implemented`.

---

## 🔔 Signals

### `mode_changed`
Emitted when the theme mode is successfully changed.

### `current_theme_changed`
Emitted when the active theme is successfully changed.

---

## 📁 Storage
Themes are stored in `~/.config/rde/theme/` (or the directory specified by `create_new_rde_storage`) as individual JSON files named after the theme (e.g., `Default.json`). A `themes_list.json` file maintains the registry of available themes.
