import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/audio_io/domain/repositories/master_volume_repository.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/volume_event.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/volume_state.dart';

/// Keeps the volume card in step with the `org.rde.Volume` service.
///
/// The service owns the mixer, so the card reads the state back after every
/// write instead of trusting its own guess. A drag is the one exception: the
/// slider follows the pointer immediately, and the value is committed once the
/// drag settles, because writing every pixel of a drag would flood the service.
///
/// Signals from the service mean another client changed the volume - media
/// keys, the shell's OSD - so the card reloads for those as well.
class VolumeBloc extends Bloc<VolumeEvent, VolumeState> {
  VolumeBloc({
    required this._repository,
    this.commitDelay = const Duration(milliseconds: 180),
  }) : super(const VolumeState.initial()) {
    on<VolumeInitEvent>(_onInit);
    on<VolumeSliderChangedEvent>(_onSliderChanged);
    on<VolumeSetEvent>(_onSet);
    on<ToggleVolumeMuteEvent>(_onToggleMute);
    on<VolumeServiceChangedEvent>(_onServiceChanged);

    _changes = _repository.watchChanges().listen(
      (_) => add(const VolumeServiceChangedEvent()),
      onError: (Object _) {
        // A service that quits mid-watch surfaces here; the next read
        // reconciles and reports the missing service.
      },
    );
  }

  /// How long a drag may settle before the value is written.
  final Duration commitDelay;

  final MasterVolumeRepository _repository;

  /// Live updates pushed by the service while the card is open.
  late final StreamSubscription<void> _changes;

  /// Collapses a burst of service signals into a single read.
  Timer? _changeDebounce;

  /// Commits the value a drag left behind.
  Timer? _volumeCommit;

  @override
  Future<void> close() async {
    _changeDebounce?.cancel();
    _volumeCommit?.cancel();
    await _changes.cancel();
    return super.close();
  }

  Future<void> _onInit(
    VolumeInitEvent event,
    Emitter<VolumeState> emit,
  ) async {
    emit(state.copyWith(status: VolumeStatus.loading, errorMessage: null));

    final result = await _repository.read();
    switch (result) {
      case Left(value: final failure):
        emit(
          state.copyWith(
            status: VolumeStatus.failure,
            errorMessage: failure.message,
          ),
        );

      case Right(value: final master):
        emit(
          state.copyWith(
            status: VolumeStatus.success,
            master: master,
            errorMessage: null,
          ),
        );
    }
  }

  /// Moves the slider and schedules the write.
  ///
  /// The state changes right away so the thumb tracks the pointer; the service
  /// is written once the drag has been still for [commitDelay].
  void _onSliderChanged(
    VolumeSliderChangedEvent event,
    Emitter<VolumeState> emit,
  ) {
    final master = state.master;
    if (master == null) {
      return;
    }

    final volume = event.volume
        .clamp(master.minVolume, master.maxVolume)
        .toInt();
    emit(
      state.copyWith(master: master.copyWith(volume: volume), errorMessage: null),
    );

    _volumeCommit?.cancel();
    _volumeCommit = Timer(commitDelay, () => add(VolumeSetEvent(volume)));
  }

  Future<void> _onSet(VolumeSetEvent event, Emitter<VolumeState> emit) async {
    final master = state.master;
    if (master == null) {
      return;
    }

    _volumeCommit?.cancel();

    final volume = event.volume
        .clamp(master.minVolume, master.maxVolume)
        .toInt();
    emit(
      state.copyWith(master: master.copyWith(volume: volume), errorMessage: null),
    );

    final result = await _repository.setVolume(volume);
    final failure = _failureOf(result);
    if (failure != null) {
      emit(state.copyWith(errorMessage: failure.message));
    }

    // The service is the truth: a rejected write snaps the slider back.
    await _refresh(emit);
  }

  Future<void> _onToggleMute(
    ToggleVolumeMuteEvent event,
    Emitter<VolumeState> emit,
  ) async {
    final master = state.master;
    if (master == null || state.isBusy) {
      return;
    }

    emit(state.copyWith(isBusy: true, errorMessage: null));

    final result = await _repository.setMuted(!master.muted);
    final failure = _failureOf(result);
    if (failure != null) {
      emit(state.copyWith(isBusy: false, errorMessage: failure.message));
      return;
    }

    await _refresh(emit);
  }

  /// Reloads after another client changed the volume.
  ///
  /// A drag in progress is left alone: the user's finger is the more recent
  /// intent, and its commit reads the service back anyway.
  Future<void> _onServiceChanged(
    VolumeServiceChangedEvent event,
    Emitter<VolumeState> emit,
  ) async {
    if (_volumeCommit?.isActive ?? false) {
      return;
    }

    _changeDebounce?.cancel();
    final completer = Completer<void>();
    _changeDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    await completer.future;
    if (state.isBusy) {
      return;
    }

    await _refresh(emit);
  }

  /// Reads the volume back from the service.
  ///
  /// A failed read keeps the volume the card already shows and only reports the
  /// error, because a service that is restarting should not blank the card.
  Future<void> _refresh(Emitter<VolumeState> emit) async {
    final result = await _repository.read();
    switch (result) {
      case Left(value: final failure):
        emit(state.copyWith(isBusy: false, errorMessage: failure.message));

      case Right(value: final master):
        emit(
          state.copyWith(
            status: VolumeStatus.success,
            master: master,
            isBusy: false,
            errorMessage: null,
          ),
        );
    }
  }

  /// Extracts the failure of a void result, or `null` on success.
  Failure? _failureOf(Either<Failure, void> result) {
    return result.fold((failure) => failure, (_) => null);
  }
}
