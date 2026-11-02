import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/audio_io/domain/entities/audio_devices.dart';
import 'package:rde_settings/features/audio_io/domain/repositories/audio_devices_repository.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/audio_devices_event.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/audio_devices_state.dart';

/// Keeps the speaker name and the microphone in step with PipeWire.
///
/// A write is shown immediately: the card moves to the selected output, input,
/// capture level or mute state as soon as the write succeeds, without reading
/// the devices back. A rejected write restores the previous devices and reports
/// the failure. A slider drag is still committed once it settles, the same
/// bargain the master volume card makes.
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
    emit(
      state.copyWith(status: AudioDevicesStatus.loading, errorMessage: null),
    );

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
  /// The selection moves as soon as the write succeeds; a rejection restores
  /// the output the card was showing.
  Future<void> _onSelectOutput(
    SelectAudioOutputEvent event,
    Emitter<AudioDevicesState> emit,
  ) async {
    final devices = state.devices;
    if (devices == null || state.isBusy) {
      return;
    }

    emit(
      state.copyWith(
        isBusy: true,
        devices: _routeOutput(devices, event.name),
        errorMessage: null,
      ),
    );

    final failure = _failureOf(await _repository.setDefaultOutput(event.name));
    if (failure != null) {
      emit(
        state.copyWith(
          isBusy: false,
          devices: devices,
          errorMessage: failure.message,
        ),
      );
      return;
    }

    emit(state.copyWith(isBusy: false));
  }

  /// Takes recordings from another input.
  ///
  /// The selection moves as soon as the write succeeds, like the output switch.
  Future<void> _onSelectInput(
    SelectAudioInputEvent event,
    Emitter<AudioDevicesState> emit,
  ) async {
    final devices = state.devices;
    if (devices == null || state.isBusy) {
      return;
    }

    emit(
      state.copyWith(
        isBusy: true,
        devices: _routeInput(devices, event.name),
        errorMessage: null,
      ),
    );

    final failure = _failureOf(await _repository.setDefaultInput(event.name));
    if (failure != null) {
      emit(
        state.copyWith(
          isBusy: false,
          devices: devices,
          errorMessage: failure.message,
        ),
      );
      return;
    }

    emit(state.copyWith(isBusy: false));
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

    // A successful write is the new level: no read-back and no waiting for the
    // audio server to echo it.
    final failure = _failureOf(await _repository.setInputVolume(volume));
    if (failure != null) {
      emit(state.copyWith(devices: devices, errorMessage: failure.message));
    }
  }

  Future<void> _onToggleMute(
    ToggleMicrophoneMuteEvent event,
    Emitter<AudioDevicesState> emit,
  ) async {
    final devices = state.devices;
    if (devices == null || !devices.hasInput || state.isBusy) {
      return;
    }

    // Flip the icon immediately; a rejected write flips it back.
    emit(
      state.copyWith(
        isBusy: true,
        devices: devices.copyWith(inputMuted: !devices.inputMuted),
        errorMessage: null,
      ),
    );

    final failure = _failureOf(
      await _repository.setInputMuted(!devices.inputMuted),
    );
    if (failure != null) {
      emit(
        state.copyWith(
          isBusy: false,
          devices: devices,
          errorMessage: failure.message,
        ),
      );
      return;
    }

    emit(state.copyWith(isBusy: false));
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

  /// Returns [devices] with [name] marked as the default sink.
  AudioDevices _routeOutput(AudioDevices devices, String name) {
    String? label;
    final outputs = <AudioOutput>[];

    for (final output in devices.outputs) {
      final isDefault = output.name == name;
      if (isDefault) {
        label = output.label;
      }

      outputs.add(
        AudioOutput(
          name: output.name,
          label: output.label,
          volume: output.volume,
          muted: output.muted,
          isDefault: isDefault,
        ),
      );
    }

    return AudioDevices(
      outputName: name,
      outputLabel: label ?? devices.outputLabel,
      outputs: outputs,
      inputName: devices.inputName,
      inputLabel: devices.inputLabel,
      inputs: devices.inputs,
      inputVolume: devices.inputVolume,
      inputMuted: devices.inputMuted,
    );
  }

  /// Returns [devices] with [name] marked as the default source.
  AudioDevices _routeInput(AudioDevices devices, String name) {
    String? label;
    final inputs = <AudioInput>[];

    for (final input in devices.inputs) {
      final isDefault = input.name == name;
      if (isDefault) {
        label = input.label;
      }

      inputs.add(
        AudioInput(
          name: input.name,
          label: input.label,
          volume: input.volume,
          muted: input.muted,
          isDefault: isDefault,
        ),
      );
    }

    return AudioDevices(
      outputName: devices.outputName,
      outputLabel: devices.outputLabel,
      outputs: devices.outputs,
      inputName: name,
      inputLabel: label ?? devices.inputLabel,
      inputs: inputs,
      inputVolume: devices.inputVolume,
      inputMuted: devices.inputMuted,
    );
  }

  /// Extracts the failure of a void result, or `null` on success.
  Failure? _failureOf(Either<Failure, void> result) {
    return result.fold((failure) => failure, (_) => null);
  }
}
