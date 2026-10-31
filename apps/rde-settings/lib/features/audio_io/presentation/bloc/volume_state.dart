import 'package:rde_settings/features/audio_io/domain/entities/master_volume.dart';

enum VolumeStatus { initial, loading, success, failure }

class VolumeState {
  /// Sentinel that distinguishes "keep the value" from "set it to null".
  static const Object _unset = Object();

  final VolumeStatus status;

  /// Volume the service reports, or `null` while it does not answer.
  final MasterVolume? master;

  /// Whether a mute toggle is in flight.
  final bool isBusy;

  final String? errorMessage;

  const VolumeState({
    required this.status,
    required this.master,
    this.isBusy = false,
    this.errorMessage,
  });

  const VolumeState.initial()
    : status = VolumeStatus.initial,
      master = null,
      isBusy = false,
      errorMessage = null;

  /// Whether the volume service answered.
  bool get isAvailable => master != null;

  VolumeState copyWith({
    VolumeStatus? status,
    Object? master = _unset,
    bool? isBusy,
    Object? errorMessage = _unset,
  }) {
    return VolumeState(
      status: status ?? this.status,
      master: identical(master, _unset)
          ? this.master
          : master as MasterVolume?,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}
