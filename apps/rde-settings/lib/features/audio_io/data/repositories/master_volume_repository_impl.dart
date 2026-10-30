import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/audio_io/data/datasources/dbus/volume_proxy.dart';
import 'package:rde_settings/features/audio_io/domain/entities/master_volume.dart';
import 'package:rde_settings/features/audio_io/domain/repositories/master_volume_repository.dart';

class MasterVolumeRepositoryImpl implements MasterVolumeRepository {
  const MasterVolumeRepositoryImpl(this._proxy);

  final VolumeProxy _proxy;

  @override
  Future<Either<Failure, MasterVolume>> read() async {
    final result = await _proxy.read();
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> setVolume(int volume) async {
    final result = await _proxy.setVolume(volume);
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> setMuted(bool muted) async {
    final result = await _proxy.setMuted(muted);
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Stream<void> watchChanges() => _proxy.watchChanges();
}
