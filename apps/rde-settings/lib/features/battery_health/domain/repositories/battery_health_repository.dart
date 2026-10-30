import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/battery_health/domain/entities/battery_snapshot.dart';

/// Domain port for reading and writing battery state.
///
/// Implementations live in `data/repositories/`. The use cases depend on this
/// interface, not on the D-Bus proxy or the UPower DTO, and failures are
/// reported as a [Failure] value instead of thrown.
abstract interface class BatteryHealthRepository {
  /// Emits whenever UPower or power-profiles-daemon reports a change the page
  /// has to show.
  Stream<void> watchChanges();

  /// Reads the current battery snapshot, including the active power profile.
  ///
  /// # Errors
  /// Returns a [Failure] when the source is unavailable or the payload cannot
  /// be decoded.
  Future<Either<Failure, BatterySnapshot>> getSnapshot();

  /// Enables or disables the charge threshold, if supported.
  ///
  /// No-op (and no error) if the battery does not support thresholds; the
  /// caller should check [BatterySnapshot.chargeThresholdSupported] first.
  Future<Either<Failure, void>> setChargeThresholdEnabled(bool enabled);

  /// Sets the charge end threshold, in percent (typically 60–100).
  ///
  /// No-op if the battery does not support thresholds.
  Future<Either<Failure, void>> setChargeEndThreshold(int percent);

  /// Sets the system power profile: `performance`, `balanced`, or
  /// `power-saver`.
  Future<Either<Failure, void>> setPowerProfile(String profile);
}
