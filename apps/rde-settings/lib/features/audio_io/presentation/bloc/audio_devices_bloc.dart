import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/audio_io/domain/repositories/audio_devices_repository.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/audio_devices_event.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/audio_devices_state.dart';

/// Keeps the speaker name and the microphone in step with PipeWire.
///
/// The audio server owns the devices, so the card reads them back after every
/// write. A slider drag follows the pointer immediately and is committed once
/// it settles, the same bargain the master volume card makes.
class AudioDevicesBloc extends Bloc<AudioDevicesEvent, AudioDevicesState> {
  AudioDevicesBloc({
    required this._repository,
    this.commitDelay = const Duration(milliseconds: 180),
  }) : super(const AudioDevicesState.initial()) {
    on<AudioDevicesInitEvent>(_onInit);
    on<SelectAudioOutputEvent>(_onSelectOutput);
    on<SelectAudioInputEvent>(_onSelectInput);
    on<MicrophoneVolumeChangedEvent>(_onVolumeChanged);
    on<MicrophoneVolumeSetEvent>(_onVolumeSet);
    on<ToggleMicrophoneMuteEvent>(_onToggleMute);
    on<AudioDevicesChangedEvent>(_onChanged);

    _changes = _repository.watchChanges().listen(
      (_) => add(const AudioDevicesChangedEvent()),
      onError: (Object _) {},
    );
  }

  /// How long a drag may settle before the capture level is written.
  final Duration commitDelay;

  final AudioDevicesRepository _repository;

  /// Live updates pushed by the audio server while the card is open.
  late final StreamSubscription<void> _changes;

  /// Collapses a burst of server events into a single read.
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
    AudioDevicesInitEvent event,
    Emitter<AudioDevicesState> emit,
  ) async {
    emit(state.copyWith(status: AudioDevicesStatus.loading, errorMessage: null));

    final result = await _repository.read();
    switch (result) {
      case Left(value: final failure):
        emit(
          state.copyWith(
            status: AudioDevicesStatus.failure,
            errorMessage: failure.message,
          ),
        );

      case Right(value: final devices):
        emit(
          state.copyWith(
            status: AudioDevicesStatus.success,
            devices: devices,
            errorMessage: null,
          ),
        );
    }
  }

  /// Routes sound to another output.
  ///
  /// The switch is read back like every other write, because the audio server
  /// decides which sink ends up default when one of them disappears mid-call.
  Future<void> _onSelectOutput(
    SelectAudioOutputEvent event,
    Emitter<AudioDevicesState> emit,
  ) async {
    final devices = state.devices;
    if (devices == null || state.isBusy) {
      return;
    }

    emit(state.copyWith(isBusy: true, errorMessage: null));

    final result = await _repository.setDefaultOutput(event.name);
    final failure = _failureOf(result);
    if (failure != null) {
      emit(state.copyWith(isBusy: false, errorMessage: failure.message));
      return;
    }

    await _refresh(emit);
  }

  /// Takes recordings from another input.
  ///
  /// Read back like every other write, for the same reason the output switch
  /// is: the audio server decides where the default lands.
  Future<void> _onSelectInput(
    SelectAudioInputEvent event,
    Emitter<AudioDevicesState> emit,
  ) async {
    final devices = state.devices;
    if (devices == null || state.isBusy) {
      return;
    }

    emit(state.copyWith(isBusy: true, errorMessage: null));

    final result = await _repository.setDefaultInput(event.name);
    final failure = _failureOf(result);
    if (failure != null) {
      emit(state.copyWith(isBusy: false, errorMessage: failure.message));
      return;
    }

    await _refresh(emit);
  }

  void _onVolumeChanged(
    MicrophoneVolumeChangedEvent event,
    Emitter<AudioDevicesState> emit,
  ) {
    final devices = state.devices;
    if (devices == null || !devices.hasInput) {
      return;
    }

    final volume = event.volume.clamp(0, 100).toInt();
    emit(
      state.copyWith(
        devices: devices.copyWith(inputVolume: volume),
        errorMessage: null,
      ),
    );

    _volumeCommit?.cancel();
    _volumeCommit = Timer(
      commitDelay,
      () => add(MicrophoneVolumeSetEvent(volume)),
    );
  }

  Future<void> _onVolumeSet(
    MicrophoneVolumeSetEvent event,
    Emitter<AudioDevicesState> emit,
  ) async {
    final devices = state.devices;
    if (devices == null || !devices.hasInput) {
      return;
    }

    _volumeCommit?.cancel();

    final volume = event.volume.clamp(0, 100).toInt();
    emit(state.copyWith(devices: devices.copyWith(inputVolume: volume)));

    final result = await _repository.setInputVolume(volume);
    final failure = _failureOf(result);
    if (failure != null) {
      emit(state.copyWith(errorMessage: failure.message));
    }

    await _refresh(emit);
  }

  Future<void> _onToggleMute(
    ToggleMicrophoneMuteEvent event,
    Emitter<AudioDevicesState> emit,
  ) async {
    final devices = state.devices;
    if (devices == null || !devices.hasInput || state.isBusy) {
      return;
    }

    emit(state.copyWith(isBusy: true, errorMessage: null));

    final result = await _repository.setInputMuted(!devices.inputMuted);
    final failure = _failureOf(result);
    if (failure != null) {
      emit(state.copyWith(isBusy: false, errorMessage: failure.message));
      return;
    }

    await _refresh(emit);
  }

  /// Reloads after the audio server reported a change.
  Future<void> _onChanged(
    AudioDevicesChangedEvent event,
    Emitter<AudioDevicesState> emit,
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

  /// Reads the devices back, keeping what the card shows on a failed read.
  Future<void> _refresh(Emitter<AudioDevicesState> emit) async {
    final result = await _repository.read();
    switch (result) {
      case Left(value: final failure):
        emit(state.copyWith(isBusy: false, errorMessage: failure.message));

      case Right(value: final devices):
        emit(
          state.copyWith(
            status: AudioDevicesStatus.success,
            devices: devices,
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
