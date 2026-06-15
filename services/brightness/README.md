# RDE Brightness

A simple and efficient D-Bus service for controlling screen brightness on Linux.

## D-Bus API

**Service:** `org.rde.Brightness`  
**Object Path:** `/org/rde/Brightness`  
**Interface:** `org.rde.Brightness`

### Properties

| Property | Type | Access | Description |
| :--- | :--- | :--- | :--- |
| `Brightness` | `u16` | Read/Write | Raw brightness value (0 - Max) |
| `BrightnessPercentage` | `u8` | Read/Write | Brightness level (0 - 100%) |
| `MaxBrightness` | `u16` | Read-only | Maximum possible brightness value |

### Methods

| Method | Input | Description |
| :--- | :--- | :--- |
| `IncreaseBrightness` | `u16` (value) | Increase brightness by raw value |
| `DecreaseBrightness` | `u16` (value) | Decrease brightness by raw value |
| `IncreaseBrightnessPercentage` | `u8` (percent) | Increase brightness by percentage |
| `DecreaseBrightnessPercentage` | `u8` (percent) | Decrease brightness by percentage |

### Signals

| Signal | Output | Description |
| :--- | :--- | :--- |
| `BrightnessChanged` | `u8` (percent) | Emitted when brightness changes |

## Usage Examples

```bash
# Get current brightness percentage
busctl --user get-property org.rde.Brightness /org/rde/Brightness org.rde.Brightness BrightnessPercentage

# Set brightness to 50%
busctl --user set-property org.rde.Brightness /org/rde/Brightness org.rde.Brightness BrightnessPercentage y 50

# Increase brightness by 10%
busctl --user set-property org.rde.Brightness /org/rde/Brightness org.rde.Brightness IncreaseBrightnessPercentage y 10

# Monitor brightness changes
busctl --user monitor org.rde.Brightness
```

## Installation

The service requires `pkexec` and a helper binary for permission management. Ensure the provided polkit policies are installed.
