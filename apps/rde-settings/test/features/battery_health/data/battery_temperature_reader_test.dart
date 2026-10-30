import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rde_settings/features/battery_health/data/datasources/sysfs/battery_temperature_reader.dart';

/// Builds a fake `/sys/class/hwmon` tree for one test.
Future<Directory> _hwmonTree(Map<String, Map<String, String>> devices) async {
  final root = await Directory.systemTemp.createTemp('hwmon');
  for (final entry in devices.entries) {
    final device = Directory('${root.path}/${entry.key}');
    await device.create(recursive: true);
    for (final file in entry.value.entries) {
      await File('${device.path}/${file.key}').writeAsString(file.value);
    }
  }
  return root;
}

void main() {
  test('reads the battery sensor in millidegrees as Celsius', () async {
    final root = await _hwmonTree({
      'hwmon0': {'name': 'ADP1'},
      'hwmon1': {'name': 'acpitz', 'temp1_input': '27800'},
      // hwmon reports millidegrees: 31000 = 31 °C.
      'hwmon2': {
        'name': 'BAT0',
        'temp1_input': '31000',
        'temp1_label': 'Battery',
      },
    });
    addTearDown(() => root.delete(recursive: true));

    final reader = BatteryTemperatureReader(hwmonRoot: root.path);

    expect(await reader.read(), 31);
  });

  test('returns null when the battery node exports no sensor', () async {
    // This is the shape of the hwmon node on this machine: the battery driver
    // publishes only voltage and power, so there is no temperature to read.
    final root = await _hwmonTree({
      'hwmon0': {'name': 'ADP1'},
      'hwmon1': {'name': 'acpitz', 'temp1_input': '27800'},
      'hwmon2': {
        'name': 'BAT0',
        'in0_input': '12943',
        'power1_input': '32344000',
      },
    });
    addTearDown(() => root.delete(recursive: true));

    final reader = BatteryTemperatureReader(hwmonRoot: root.path);

    // The ambient `acpitz` reading must not be borrowed as the battery.
    expect(await reader.read(), isNull);
  });

  test('returns null when there is no battery node at all', () async {
    final root = await _hwmonTree({
      'hwmon0': {'name': 'coretemp', 'temp1_input': '52000'},
    });
    addTearDown(() => root.delete(recursive: true));

    final reader = BatteryTemperatureReader(hwmonRoot: root.path);

    expect(await reader.read(), isNull);
  });

  test('rejects a value in the wrong unit instead of showing 310 °C', () async {
    final root = await _hwmonTree({
      'hwmon2': {'name': 'BAT0', 'temp1_input': '310000'},
    });
    addTearDown(() => root.delete(recursive: true));

    final reader = BatteryTemperatureReader(hwmonRoot: root.path);

    expect(await reader.read(), isNull);
  });

  test('ignores a zero reading, which means the sensor read failed', () async {
    final root = await _hwmonTree({
      'hwmon2': {'name': 'BAT0', 'temp1_input': '0'},
    });
    addTearDown(() => root.delete(recursive: true));

    final reader = BatteryTemperatureReader(hwmonRoot: root.path);

    expect(await reader.read(), isNull);
  });

  test('prefers the sensor the driver labels as the battery', () async {
    final root = await _hwmonTree({
      'hwmon2': {
        'name': 'BAT0',
        'temp1_input': '27000',
        'temp1_label': 'Ambient',
        'temp2_input': '31000',
        'temp2_label': 'Battery',
      },
    });
    addTearDown(() => root.delete(recursive: true));

    final reader = BatteryTemperatureReader(hwmonRoot: root.path);

    expect(await reader.read(), 31);
  });

  test('returns null when the hwmon tree does not exist', () async {
    final reader = BatteryTemperatureReader(
      hwmonRoot: '/nonexistent-hwmon-root-for-test',
    );

    expect(await reader.read(), isNull);
  });
}
