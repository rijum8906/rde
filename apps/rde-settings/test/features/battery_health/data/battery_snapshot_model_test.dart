import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rde_settings/features/battery_health/data/models/battery_snapshot_model.dart';

/// The properties of a real battery, copied from
/// `busctl introspect org.freedesktop.UPower /org/freedesktop/UPower/devices/battery_BAT0`:
/// the state and thresholds are `u`, the cycle count is `i`, and the time
/// estimates are `x`.
Map<String, DBusValue> _upowerReply() {
  return {
    'BatteryLevel': DBusUint32(1),
    'Capacity': DBusDouble(99.55),
    'ChargeCycles': DBusInt32(408),
    'ChargeEndThreshold': DBusUint32(0),
    'ChargeStartThreshold': DBusUint32(0),
    'ChargeThresholdEnabled': DBusBoolean(false),
    'ChargeThresholdSupported': DBusBoolean(true),
    'EnergyFull': DBusDouble(59.73),
    'EnergyFullDesign': DBusDouble(60),
    'Model': DBusString('L24B3PK2'),
    'Percentage': DBusDouble(18),
    'State': DBusUint32(1),
    'Temperature': DBusDouble(0),
    'TimeToEmpty': DBusInt64(0),
    'TimeToFull': DBusInt64(3962),
    'Type': DBusUint32(2),
    'Vendor': DBusString('BYD'),
  };
}

void main() {
  test('decodes the types a real UPower battery reports', () {
    final snapshot = const BatterySnapshotModel().fromDBus(_upowerReply());

    expect(snapshot.percentage, 18);
    expect(snapshot.isCharging, isTrue);
    expect(snapshot.healthPercent, 99.55);
    expect(snapshot.cycleCount, 408);
    expect(snapshot.energyFullWh, 59.73);
    expect(snapshot.energyFullDesignWh, 60);
    expect(snapshot.model, 'L24B3PK2');
    expect(snapshot.vendor, 'BYD');
  });

  test('reads the x-typed time estimates and u-typed thresholds', () {
    final snapshot = const BatterySnapshotModel().fromDBus(_upowerReply());

    expect(snapshot.timeToEmptySeconds, 0);
    expect(snapshot.timeToFullSeconds, 3962);
    expect(snapshot.timeRemainingLabel, '1h 6m until full');
    expect(snapshot.chargeThresholdSupported, isTrue);
    expect(snapshot.chargeThresholdEnabled, isFalse);
    expect(snapshot.chargeEndThreshold, 0);
    expect(snapshot.chargeStartThreshold, 0);
  });

  test('keeps an absent temperature unknown instead of zero', () {
    final snapshot = const BatterySnapshotModel().fromDBus(_upowerReply());

    expect(snapshot.temperatureCelsius, isNull);
  });

  test('accepts an unsigned cycle count as well', () {
    final snapshot = const BatterySnapshotModel().fromDBus({
      ..._upowerReply(),
      'ChargeCycles': DBusUint32(408),
    });

    expect(snapshot.cycleCount, 408);
  });
}
