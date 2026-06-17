# rde-brightness Documentation

This document provides a detailed technical reference for the `rde-brightness` D-Bus service, including all properties, methods, and signals.

## 📡 D-Bus Interface Overview

- **Service Name**: `org.rde.Brightness`
- **Object Path**: `/org/rde/Brightness`
- **Interface**: `org.rde.Brightness`

---

## 🛠 Data Structures

### `BacklightType` (Enum - Internal)
Supported backlight types identified by the service.
- `Intel`
- `Amd`
- `Nvidia`
- `Acpi`
- `Generic`

---

## 🏠 Properties

### `Brightness`
- **Type**: `u16`
- **Access**: Read/Write
- **Description**: Gets or sets the current raw brightness value.
- **Constraints**: Must be between `0` and `MaxBrightness`.

### `BrightnessPercentage`
- **Type**: `u8`
- **Access**: Read/Write
- **Description**: Gets or sets the current brightness as a percentage.
- **Values**: `0` to `100`.

### `MaxBrightness`
- **Type**: `u16`
- **Access**: Read Only
- **Description**: Returns the maximum raw brightness value supported by the detected hardware.

---

## ⚙️ Methods

### `increase_brightness`
Increases the current brightness by a specific raw value.
- **Arguments**:
  - `value`: `u16` (The amount to increase).
- **Returns**: `void`
- **Notes**: Automatically capped at `MaxBrightness`. Emits `BrightnessChanged`.

### `decrease_brightness`
Decreases the current brightness by a specific raw value.
- **Arguments**:
  - `value`: `u16` (The amount to decrease).
- **Returns**: `void`
- **Notes**: Automatically floored at `0`. Emits `BrightnessChanged`.

### `increase_brightness_percentage`
Increases the current brightness by a specific percentage.
- **Arguments**:
  - `value`: `u8` (Percentage points to increase).
- **Returns**: `void`
- **Notes**: Automatically capped at `100%`. Emits `BrightnessChanged`.

### `decrease_brightness_percentage`
Decreases the current brightness by a specific percentage.
- **Arguments**:
  - `value`: `u8` (Percentage points to decrease).
- **Returns**: `void`
- **Notes**: Automatically floored at `0%`. Emits `BrightnessChanged`.

---

## 🔔 Signals

### `BrightnessChanged`
Emitted when the brightness level is modified via any method or property setter.
- **Payload**: `percent` (`u8`): The new brightness level as a percentage.

---

## 📁 Hardware Interaction
The service interacts with the Linux kernel via the sysfs interface located at `/sys/class/backlight/`. It automatically detects the first available backlight device.

Writing to `brightness` files in sysfs typically requires root privileges. `rde-brightness` handles this by invoking a small helper binary (`rde-brightness-helper`) via `pkexec`. For production deployments, a Polkit policy or Udev rule is recommended to allow the service to write without password prompts.
