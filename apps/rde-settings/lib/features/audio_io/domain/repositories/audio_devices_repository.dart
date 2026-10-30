import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/audio_io/domain/entities/audio_devices.dart';

/// Reads the default output/input devices and controls the microphone.
abstract interface class AudioDevicesRepository {
  /// Reads the default sink and source, with the microphone's capture level.
  Future<Either<Failure, AudioDevices>> read();

  /// Makes [name] the output sound is routed to.
  Future<Either<Failure, void>> setDefaultOutput(String name);

  /// Makes [name] the input recordings are taken from.
  Future<Either<Failure, void>> setDefaultInput(String name);

  /// Sets the microphone capture volume to [volume] percent.
  Future<Either<Failure, void>> setInputVolume(int volume);

  /// Mutes or unmutes the microphone.
  Future<Either<Failure, void>> setInputMuted(bool muted);

  /// Emits whenever PipeWire reports a sink or source change.
  Stream<void> watchChanges();
}
