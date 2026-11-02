import 'package:rde_settings/features/display/domain/entities/brightness_level.dart';

enum BrightnessStatus { initial, loading, success, failure }

class BrightnessState {
  /// Sentinel that distinguishes "keep the value" from "set it to null".
  static const Object _unset = Object();

  final BrightnessStatus status;

  /// Brightness the service reports, or `null` while it does not answer.
  final BrightnessLevel? level;

  /// Whether a stepped change is in flight.
  final bool isBusy;

  final String? errorMessage;

  const BrightnessState({
    required this.status,
    required this.level,
    this.isBusy = false,
    this.errorMessage,
  });

  const BrightnessState.initial()
    : status = BrightnessStatus.initial,
      level = null,
      isBusy = false,
      errorMessage = null;

  /// Whether the brightness service answered.
  bool get isAvailable => level != null;

  /// Whether sliders and step buttons may write to the service.
  bool get canChange => level != null && status == BrightnessStatus.success;

  BrightnessState copyWith({
    BrightnessStatus? status,
    Object? level = _unset,
    bool? isBusy,
    Object? errorMessage = _unset,
  }) {
    return BrightnessState(
      status: status ?? this.status,
      level: identical(level, _unset) ? this.level : level as BrightnessLevel?,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}
