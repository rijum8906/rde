import 'package:equatable/equatable.dart';
import 'package:rde_settings/features/battery_health/domain/entities/battery_snapshot.dart';

enum BatteryHealthStatus { initial, loading, success, failure }

class BatteryHealthState extends Equatable {
  const BatteryHealthState({
    this.status = BatteryHealthStatus.initial,
    this.snapshot,
    this.powerSaverActive = false,
    this.errorMessage,
    this.isBusy = false,
  });

  final BatteryHealthStatus status;
  final BatterySnapshot? snapshot;
  final bool powerSaverActive;
  final String? errorMessage;
  final bool isBusy;

  BatteryHealthState copyWith({
    BatteryHealthStatus? status,
    BatterySnapshot? snapshot,
    bool? powerSaverActive,
    String? errorMessage,
    bool clearError = false,
    bool? isBusy,
  }) {
    return BatteryHealthState(
      status: status ?? this.status,
      snapshot: snapshot ?? this.snapshot,
      powerSaverActive: powerSaverActive ?? this.powerSaverActive,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isBusy: isBusy ?? this.isBusy,
    );
  }

  @override
  List<Object?> get props => [
    status,
    snapshot,
    powerSaverActive,
    errorMessage,
    isBusy,
  ];
}
