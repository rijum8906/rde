import 'package:flutter_bloc/flutter_bloc.dart';
import 'battery_health_event.dart';
import 'battery_health_state.dart';

class BatteryHealthBloc extends Bloc<BatteryHealthEvent, BatteryHealthState> {
  BatteryHealthBloc() : super(BatteryHealthState.initial()) {
    on<TogglePowerSavingEvent>((event, emit) {
      emit(state.copyWith(powerSavingMode: event.value));
    });
    on<ToggleHealthProtectionEvent>((event, emit) {
      emit(state.copyWith(healthProtection: event.value));
    });
    on<ChangeChargeLimitEvent>((event, emit) {
      emit(state.copyWith(chargeLimit: event.value));
    });
  }
}
