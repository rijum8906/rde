import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/audio_io/domain/entities/master_volume.dart';

/// Reads and writes the master volume through `org.rde.Volume`.
abstract interface class MasterVolumeRepository {
  /// Reads the volume the service currently reports.
  Future<Either<Failure, MasterVolume>> read();

  /// Sets the master volume to [volume] percent.
  Future<Either<Failure, void>> setVolume(int volume);

  /// Mutes or unmutes playback.
  Future<Either<Failure, void>> setMuted(bool muted);

  /// Emits whenever the service reports a volume or mute change.
  Stream<void> watchChanges();
}
