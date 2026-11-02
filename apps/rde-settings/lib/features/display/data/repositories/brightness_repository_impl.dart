import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/display/data/datasources/dbus/brightness_proxy.dart';
import 'package:rde_settings/features/display/domain/entities/brightness_level.dart';
import 'package:rde_settings/features/display/domain/repositories/brightness_repository.dart';

class BrightnessRepositoryImpl implements BrightnessRepository {
  const BrightnessRepositoryImpl(this._proxy);

  final BrightnessProxy _proxy;

  @override
  Future<Either<Failure, BrightnessLevel>> read() async {
    final result = await _proxy.read();
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> setPercent(int percent) async {
    final result = await _proxy.setPercent(percent);
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> increase(int step) async {
    final result = await _proxy.increase(step);
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> decrease(int step) async {
    final result = await _proxy.decrease(step);
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Stream<void> watchChanges() => _proxy.watchChanges();
}
