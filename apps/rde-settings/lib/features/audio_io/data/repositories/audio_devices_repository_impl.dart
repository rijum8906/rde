import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/audio_io/data/datasources/pactl_audio_datasource.dart';
import 'package:rde_settings/features/audio_io/domain/entities/audio_devices.dart';
import 'package:rde_settings/features/audio_io/domain/repositories/audio_devices_repository.dart';

class AudioDevicesRepositoryImpl implements AudioDevicesRepository {
  const AudioDevicesRepositoryImpl(this._datasource);

  final PactlAudioDatasource _datasource;

  @override
  Future<Either<Failure, AudioDevices>> read() async {
    final result = await _datasource.read();
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> setDefaultOutput(String name) async {
    final result = await _datasource.setDefaultOutput(name);
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> setDefaultInput(String name) async {
    final result = await _datasource.setDefaultInput(name);
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> setInputVolume(int volume) async {
    final result = await _datasource.setInputVolume(volume);
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> setInputMuted(bool muted) async {
    final result = await _datasource.setInputMuted(muted);
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Stream<void> watchChanges() => _datasource.watchChanges();
}
