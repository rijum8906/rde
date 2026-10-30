import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/battery_health/data/datasources/dbus/power_profiles_proxy.dart';
import 'package:rde_settings/features/battery_health/data/datasources/dbus/upower_proxy.dart';
import 'package:rde_settings/features/battery_health/data/datasources/sysfs/battery_temperature_reader.dart';
import 'package:rde_settings/features/battery_health/domain/entities/battery_snapshot.dart';

/// Maps the page's battery operations onto the UPower proxies.
///
/// The battery and the power profile come from two daemons, so this datasource
/// is the single place that fans out to both and merges their signals into one
/// stream.
class DbusBatteryHealthDatasource {
  DbusBatteryHealthDatasource({
    required this._upower,
    required this._powerProfiles,
    this._temperature = const BatteryTemperatureReader(),
  });

  final UPowerProxy _upower;
  final PowerProfilesProxy _powerProfiles;
  final BatteryTemperatureReader _temperature;

  /// Watches UPower and power-profiles-daemon for events that change the page.
  ///
  /// The two watch streams are merged so the page has one subscription to
  /// cancel, and the merged stream is broadcast so a second listener does not
  /// open a second set of D-Bus watches.
  Stream<void> watchChanges() {
    late final StreamController<void> controller;
    var subscriptions = <StreamSubscription<void>>[];
    var cancelled = false;

    // Step 1: Publish one event to every listener, tolerating late arrivals.
    void emit() {
      if (!cancelled && controller.hasListener) {
        controller.add(null);
      }
    }

    // Step 2: Keep both watches alive for exactly as long as the page listens.
    controller = StreamController<void>.broadcast(
      onListen: () {
        cancelled = false;
        subscriptions.add(
          _upower.watchChanges().listen((_) => emit(), onError: (Object _) {}),
        );
        subscriptions.add(
          _powerProfiles.watchChanges().listen(
            (_) => emit(),
            onError: (Object _) {},
          ),
        );
      },
      onCancel: () async {
        cancelled = true;
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        subscriptions = [];
      },
    );
    return controller.stream;
  }

  /// Reads the battery, its temperature, and the active power profile.
  ///
  /// The temperature and the profile are optional: a machine whose battery
  /// driver does not export a sensor, or that has no power-profiles-daemon,
  /// still gets a usable page. Only a failed battery read fails the snapshot.
  ///
  /// # Errors
  /// Returns an [RdeError] when UPower cannot be reached.
  Future<Either<RdeError, BatterySnapshot>> getSnapshot() async {
    final result = await _upower.snapshot();
    return result.fold<Future<Either<RdeError, BatterySnapshot>>>(
      (error) async => Left(error),
      (snapshot) async {
        // UPower reports `Temperature = 0` on batteries that do not publish
        // `POWER_SUPPLY_TEMP`, so the hwmon sensor is read when the daemon has
        // no reading of its own.
        final temperature =
            snapshot.temperatureCelsius ?? await _temperature.read();
        final profile = await _powerProfiles.activeProfile();

        return Right<RdeError, BatterySnapshot>(
          snapshot.copyWith(
            temperatureCelsius: temperature,
            activePowerProfile: profile.fold<String?>(
              (_) => null,
              (value) => value,
            ),
          ),
        );
      },
    );
  }

  /// Enables or disables the charge threshold, if supported.
  Future<Either<RdeError, void>> setChargeThresholdEnabled(bool enabled) {
    return _upower.enableChargeThreshold(enabled);
  }

  /// Sets the charge end threshold, in percent (typically 60–100).
  Future<Either<RdeError, void>> setChargeEndThreshold(int percent) {
    return _upower.setChargeEndThreshold(percent);
  }

  /// Sets the system power profile: `performance`, `balanced`, or
  /// `power-saver`.
  Future<Either<RdeError, void>> setPowerProfile(String profile) {
    return _powerProfiles.setActiveProfile(profile);
  }
}
