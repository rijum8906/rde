import 'package:dbus/dbus.dart';
import 'package:rde_settings/features/battery_health/domain/entities/battery_snapshot.dart';

/// Decodes a UPower `GetAll` reply into a domain [BatterySnapshot].
///
/// UPower is not consistent about numeric widths: `State` and the charge
/// thresholds are `u`, `ChargeCycles` is `i`, `TimeToEmpty`/`TimeToFull` are
/// `x`, and the energy values are `d`. The helpers below accept any numeric
/// D-Bus type, so a firmware that reports a different width cannot break the
/// whole read the way a hard-coded `asInt32()` does.
///
/// UPower reports `0` / `-1` for "unknown" on some hardware, so this model
/// normalizes those to `null` in the domain entity.
class BatterySnapshotModel {
  const BatterySnapshotModel();

  BatterySnapshot fromDBus(Map<String, DBusValue> map) {
    final rawTemp = _double(map['Temperature']) ?? 0;
    final rawCycles = _int(map['ChargeCycles']) ?? -1;
    final rawCapacity = _double(map['Capacity']) ?? 0;

    return BatterySnapshot(
      percentage: _double(map['Percentage']) ?? 0,
      state: _int(map['State']) ?? 0,
      healthPercent: rawCapacity > 0 ? rawCapacity : null,
      cycleCount: rawCycles >= 0 ? rawCycles : null,
      temperatureCelsius: rawTemp > 0 ? rawTemp : null,
      timeToEmptySeconds: _int(map['TimeToEmpty']) ?? 0,
      timeToFullSeconds: _int(map['TimeToFull']) ?? 0,
      energyFullWh: _double(map['EnergyFull']) ?? 0,
      energyFullDesignWh: _double(map['EnergyFullDesign']) ?? 0,
      chargeThresholdSupported: _bool(map['ChargeThresholdSupported']) ?? false,
      chargeThresholdEnabled: _bool(map['ChargeThresholdEnabled']) ?? false,
      chargeEndThreshold: _int(map['ChargeEndThreshold']) ?? 0,
      chargeStartThreshold: _int(map['ChargeStartThreshold']) ?? 0,
      model: _string(map['Model']) ?? '',
      vendor: _string(map['Vendor']) ?? '',
    );
  }

  /// Reads a floating-point property, accepting any numeric width.
  double? _double(DBusValue? value) {
    if (value is DBusDouble) return value.value;
    if (value is DBusByte) return value.value.toDouble();
    if (value is DBusInt16) return value.value.toDouble();
    if (value is DBusUint16) return value.value.toDouble();
    if (value is DBusInt32) return value.value.toDouble();
    if (value is DBusUint32) return value.value.toDouble();
    if (value is DBusInt64) return value.value.toDouble();
    if (value is DBusUint64) return value.value.toDouble();
    return null;
  }

  /// Reads an integer property, accepting any numeric width.
  ///
  /// `TimeToEmpty` and `TimeToFull` are signed 64-bit, and the charge
  /// thresholds are unsigned 32-bit, so every width is accepted here.
  int? _int(DBusValue? value) {
    if (value is DBusByte) return value.value;
    if (value is DBusInt16) return value.value;
    if (value is DBusUint16) return value.value;
    if (value is DBusInt32) return value.value;
    if (value is DBusUint32) return value.value;
    if (value is DBusInt64) return value.value;
    if (value is DBusUint64) return value.value;
    if (value is DBusDouble) return value.value.round();
    return null;
  }

  bool? _bool(DBusValue? value) => value is DBusBoolean ? value.value : null;

  String? _string(DBusValue? value) => value is DBusString ? value.value : null;
}
