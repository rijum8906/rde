import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/audio_io/data/datasources/dbus/mpris_proxy.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';
import 'package:rde_settings/features/audio_io/domain/repositories/now_playing_repository.dart';

/// MPRIS-backed implementation of [NowPlayingRepository].
///
/// The repository is the boundary between the UI vocabulary ([Failure]) and the
/// data vocabulary ([RdeError]): every result is mapped here, so the use cases
/// and the bloc never see a D-Bus error type.
class NowPlayingRepositoryImpl implements NowPlayingRepository {
  NowPlayingRepositoryImpl(this._proxy);

  final MprisProxy _proxy;

  @override
  Stream<void> watchChanges() => _proxy.watchChanges();

  @override
  Future<Either<Failure, List<NowPlayingMedia>>> getPlayers() async {
    final result = await _proxy.players();
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> togglePlayPause(NowPlayingMedia media) async {
    final result = await _proxy.togglePlayPause(media);
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> skipToNext(NowPlayingMedia media) async {
    final result = await _proxy.skipToNext(media);
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> skipToPrevious(NowPlayingMedia media) async {
    final result = await _proxy.skipToPrevious(media);
    return result.mapLeft((error) => Failure(error.message));
  }
}
