import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/display/domain/entities/brightness_level.dart';

/// Reads and writes display brightness through `org.rde.Brightness`.
abstract interface class BrightnessRepository {
  /// Reads the brightness the service currently reports.
  Future<Either<Failure, BrightnessLevel>> read();

  /// Sets the active display to [percent].
  Future<Either<Failure, void>> setPercent(int percent);

  /// Raises the active display by [step] percentage points.
  Future<Either<Failure, void>> increase(int step);

  /// Lowers the active display by [step] percentage points.
  Future<Either<Failure, void>> decrease(int step);

  /// Emits whenever the service reports a brightness change.
  Stream<void> watchChanges();
}
