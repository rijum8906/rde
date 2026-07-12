# RDE Brightness

RDE service for brightness control.

# DBus Interface


| Name | Type | Signature | Flag | Description
| :--- | :--- |  :--- | :--- | :--- |
IncreaseBrightness   | method   | u | -           | Increases brightness by `step` percentage points. |
DecreaseBrightness   | method   | u | -           | Decreases brightness by `step` percentage points. |
Brightness           | property | u | writable    | Current brightness value. |
BrightnessPercentage | property | u | writable    | Current brightness percentage. |
Version              | property | s | emit-change | Version of the daemon. |
BrightnessChanged    | signal   | u | -           | Emitted when brightness changes. |
