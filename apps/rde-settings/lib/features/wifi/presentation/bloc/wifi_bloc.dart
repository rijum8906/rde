import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/wifi/domain/repositories/wifi_repository.dart';
import 'wifi_event.dart';
import 'wifi_state.dart';

class WifiBloc extends Bloc<WifiEvent, WifiState> {
  final WifiRepository _wifiRepository;

  WifiBloc({required WifiRepository wifiRepository})
    : _wifiRepository = wifiRepository,
      super(WifiState.initial()) {
    on<WifiInitEvent>(_onInit);
    on<ScanNetworksEvent>(_onScanNetworks);
    on<ToggleWifiRadioEvent>(_onToggleWifiRadio);
    on<ConnectToNetworkEvent>(_onConnectToNetwork);
  }

  void _onInit(WifiInitEvent event, Emitter<WifiState> emit) {
    if (state.isWifiEnabled) {
      add(const ScanNetworksEvent());
    }
  }

  Future<void> _onScanNetworks(
    ScanNetworksEvent event,
    Emitter<WifiState> emit,
  ) async {
    emit(state.copyWith(status: WifiStatus.loading, errorMessage: null));
    final res = await _wifiRepository.scanNetworks();
    res.fold(
      (failure) => emit(
        state.copyWith(
          status: WifiStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (networks) {
        final list = List.of(networks);
        if (state.connectedSsid != null) {
          final idx = list.indexWhere((n) => n.ssid == state.connectedSsid);
          if (idx != -1) {
            final connected = list.removeAt(idx);
            list.insert(0, connected);
          }
        }
        emit(state.copyWith(status: WifiStatus.success, networks: list));
      },
    );
  }

  void _onToggleWifiRadio(ToggleWifiRadioEvent event, Emitter<WifiState> emit) {
    if (event.value) {
      emit(state.copyWith(isWifiEnabled: true));
      add(const ScanNetworksEvent());
    } else {
      emit(
        state.copyWith(isWifiEnabled: false, networks: [], connectedSsid: null),
      );
    }
  }

  Future<void> _onConnectToNetwork(
    ConnectToNetworkEvent event,
    Emitter<WifiState> emit,
  ) async {
    emit(state.copyWith(connectingSsid: event.ssid));
    await Future.delayed(const Duration(milliseconds: 1200));

    final list = List.of(state.networks);
    final idx = list.indexWhere((n) => n.ssid == event.ssid);
    if (idx != -1) {
      final connected = list.removeAt(idx);
      list.insert(0, connected);
    }

    emit(
      state.copyWith(
        connectedSsid: event.ssid,
        connectingSsid: null,
        networks: list,
      ),
    );
  }
}
