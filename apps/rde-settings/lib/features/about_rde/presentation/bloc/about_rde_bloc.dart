import 'package:flutter_bloc/flutter_bloc.dart';
import 'about_rde_event.dart';
import 'about_rde_state.dart';

class AboutRdeBloc extends Bloc<AboutRdeEvent, AboutRdeState> {
  AboutRdeBloc() : super(AboutRdeState.initial()) {
    on<TriggerUpdateCheckEvent>((event, emit) async {
      if (state.status == AboutStatus.checking) return;
      emit(state.copyWith(status: AboutStatus.checking));
      await Future.delayed(const Duration(seconds: 2));
      emit(state.copyWith(status: AboutStatus.success));
    });

    on<RotateLogoEvent>((event, emit) {
      emit(state.copyWith(logoRotation: state.logoRotation + event.amount));
    });

    on<ResetUpdateStatusEvent>((event, emit) {
      emit(state.copyWith(status: AboutStatus.initial));
    });
  }
}
