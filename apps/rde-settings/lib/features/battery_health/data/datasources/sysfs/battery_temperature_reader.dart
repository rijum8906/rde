import 'dart:io';

/// Reads the battery temperature from the `hwmon` sysfs tree.
///
/// Some battery drivers do not publish `POWER_SUPPLY_TEMP`, so UPower reports
/// `Temperature = 0` even though the sensor exists. The same sensor is exported
/// through `hwmon` instead: the device whose `name` is the battery (`BAT0`,
/// matching UPower's `NativePath`) reports it in `temp*_input`, in millidegrees
/// Celsius.
///
/// Not every battery driver exports a temperature at all - a node may carry
/// only voltage and power - in which case [read] returns `null` and the page
/// keeps showing the temperature as unknown instead of borrowing a reading
/// from a CPU or ambient sensor.
class BatteryTemperatureReader {
  const BatteryTemperatureReader({this.hwmonRoot = '/sys/class/hwmon'});

  /// Directory holding the `hwmon` devices, overridable so tests can point at a
  /// fixture.
  final String hwmonRoot;

  /// Highest plausible battery temperature, in degrees Celsius.
  ///
  /// A reading above this is a value in the wrong unit or the wrong sensor, so
  /// it is treated as unknown rather than shown.
  static const double _maxPlausibleCelsius = 100;

  /// Returns the battery temperature in degrees Celsius, or `null` when no
  /// battery sensor is exposed.
  Future<double?> read() async {
    final root = Directory(hwmonRoot);
    if (!await root.exists()) {
      return null;
    }

    final List<FileSystemEntity> devices;
    try {
      devices = await root.list().toList();
    } on FileSystemException {
      return null;
    }

    for (final device in devices) {
      final name = await _readText('${device.path}/name');
      if (name == null || !_isBattery(name)) {
        continue;
      }

      final celsius = await _readBatterySensor(device.path);
      if (celsius != null) {
        return celsius;
      }
    }
    return null;
  }

  /// True for the `hwmon` node names that are a battery, such as `BAT0`.
  bool _isBattery(String name) =>
      RegExp(r'^bat\d+$', caseSensitive: false).hasMatch(name.trim());

  /// Reads the first usable temperature of one battery `hwmon` node.
  ///
  /// A node can export several sensors, so one the driver labels as the battery
  /// wins; otherwise the first usable one is used.
  Future<double?> _readBatterySensor(String path) async {
    final List<FileSystemEntity> files;
    try {
      files = await Directory(path).list().toList()
        ..sort((left, right) => left.path.compareTo(right.path));
    } on FileSystemException {
      return null;
    }

    double? fallback;
    for (final file in files) {
      final sensor = _sensorName(file.path);
      if (sensor == null) {
        continue;
      }

      final raw = int.tryParse((await _readText(file.path)) ?? '');
      if (raw == null || raw <= 0) {
        continue;
      }

      final celsius = raw / 1000;
      if (celsius > _maxPlausibleCelsius) {
        continue;
      }

      final label = await _readText('$path/${sensor}_label');
      if (label != null && label.toLowerCase().contains('batt')) {
        return celsius;
      }
      fallback ??= celsius;
    }
    return fallback;
  }

  /// Returns the `temp<N>` part of a `temp<N>_input` file name, or `null` when
  /// the file is not a temperature input.
  String? _sensorName(String filePath) {
    final name = filePath.split('/').last;
    if (!name.startsWith('temp') || !name.endsWith('_input')) {
      return null;
    }
    return name.substring(0, name.length - '_input'.length);
  }

  Future<String?> _readText(String path) async {
    try {
      return await File(path).readAsString();
    } on FileSystemException {
      return null;
    }
  }
}
