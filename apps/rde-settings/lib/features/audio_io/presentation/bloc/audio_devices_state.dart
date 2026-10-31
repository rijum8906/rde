import 'package:rde_settings/features/audio_io/domain/entities/audio_devices.dart';

enum AudioDevicesStatus { initial, loading, success, failure }

class AudioDevicesState {
  /// Sentinel that distinguishes "keep the value" from "set it to null".
  static const Object _unset = Object();

  final AudioDevicesStatus status;

  /// Devices the audio server reports, or `null` while they are unknown.
  final AudioDevices? devices;

  /// Whether a mute toggle is in flight.
  final bool isBusy;

  final String? errorMessage;

  const AudioDevicesState({
    required this.status,
    required this.devices,
    this.isBusy = false,
    this.errorMessage,
  });

  const AudioDevicesState.initial()
    : status = AudioDevicesStatus.initial,
      devices = null,
      isBusy = false,
      errorMessage = null;

  /// Whether a microphone was found.
  bool get hasInput => devices?.hasInput ?? false;

  AudioDevicesState copyWith({
    AudioDevicesStatus? status,
    Object? devices = _unset,
    bool? isBusy,
    Object? errorMessage = _unset,
  }) {
    return AudioDevicesState(
      status: status ?? this.status,
      devices: identical(devices, _unset) ? this.devices : devices as AudioDevices?,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}
