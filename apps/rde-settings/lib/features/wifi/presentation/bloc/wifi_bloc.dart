import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';
import 'package:rde_settings/features/wifi/domain/repositories/wifi_repository.dart';
import 'wifi_event.dart';
import 'wifi_state.dart';

/// Coordinates the Wi-Fi page with the NetworkManager-backed repository.
///
/// Every mutation is followed by a fresh read, so the page renders the daemon's
/// state instead of an optimistic guess.
class WifiBloc extends Bloc<WifiEvent, WifiState> {
  final WifiRepository _wifiRepository;

  WifiBloc({required this._wifiRepository}) : super(WifiState.initial()) {
    on<WifiInitEvent>(_onInit);
    on<ScanNetworksEvent>(_onScanNetworks);
    on<ToggleWifiRadioEvent>(_onToggleWifiRadio);
    on<ConnectToNetworkEvent>(_onConnectToNetwork);
    on<DismissPasswordPromptEvent>(_onDismissPasswordPrompt);
    on<LoadSavedNetworksEvent>(_onLoadSavedNetworks);
    on<ForgetSavedNetworkEvent>(_onForgetSavedNetwork);
  }

  Future<void> _onInit(WifiInitEvent event, Emitter<WifiState> emit) async {
    emit(state.copyWith(status: WifiStatus.loading, errorMessage: null));

    final enabledResult = await _wifiRepository.isWifiEnabled();
    Failure? failure;
    var enabled = false;
    enabledResult.fold((value) => failure = value, (value) => enabled = value);

    if (failure != null) {
      emit(
        state.copyWith(
          status: WifiStatus.failure,
          errorMessage: failure!.message,
        ),
      );
      return;
    }

    emit(state.copyWith(isWifiEnabled: enabled));
    if (!enabled) {
      emit(
        state.copyWith(
          status: WifiStatus.success,
          networks: const [],
          savedNetworks: const [],
          connectedSsid: null,
        ),
      );
      return;
    }

    await _refresh(emit);
  }

  Future<void> _onScanNetworks(
    ScanNetworksEvent event,
    Emitter<WifiState> emit,
  ) async {
    emit(state.copyWith(status: WifiStatus.loading, errorMessage: null));
    await _refresh(emit);
  }

  Future<void> _onToggleWifiRadio(
    ToggleWifiRadioEvent event,
    Emitter<WifiState> emit,
  ) async {
    if (event.value == state.isWifiEnabled) {
      return;
    }

    emit(state.copyWith(errorMessage: null));
    final result = await _wifiRepository.setWifiEnabled(event.value);
    final failure = _failureOf(result);
    if (failure != null) {
      emit(state.copyWith(errorMessage: failure.message));
      return;
    }

    emit(state.copyWith(isWifiEnabled: event.value));

    if (!event.value) {
      emit(
        state.copyWith(
          status: WifiStatus.success,
          networks: const [],
          savedNetworks: const [],
          connectedSsid: null,
        ),
      );
      return;
    }

    emit(state.copyWith(status: WifiStatus.loading));
    await _refresh(emit);
  }

  Future<void> _onConnectToNetwork(
    ConnectToNetworkEvent event,
    Emitter<WifiState> emit,
  ) async {
    if (state.connectingSsid != null) {
      return;
    }

    final network = _networkFor(event.ssid);
    emit(state.copyWith(connectingSsid: event.ssid, errorMessage: null));

    final result = await _wifiRepository.connectToNetwork(
      network,
      password: event.password,
    );
    final failure = _failureOf(result);
    if (failure != null) {
      // A saved profile that no longer activates usually means the stored
      // secret is stale, so ask for a password before reporting the error.
      final promptForPassword = event.password == null && event.promptOnFailure;
      emit(
        state.copyWith(
          connectingSsid: null,
          passwordPromptSsid: promptForPassword ? event.ssid : null,
          errorMessage: promptForPassword ? null : failure.message,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        connectingSsid: null,
        connectedSsid: event.ssid,
        passwordPromptSsid: null,
      ),
    );

    // NetworkManager calls are asynchronous: give the association a moment
    // before the refresh reads the authoritative state back.
    await _waitForAssociation(event.ssid);
    await _refresh(emit);
  }

  /// Polls the current network until the adapter associates with [ssid].
  ///
  /// Activation returns before the link is up, so a single read would clear the
  /// connected state the page just showed. Polling is best effort: after the
  /// budget the caller reloads and lets the daemon state win.
  Future<void> _waitForAssociation(String ssid) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final result = await _wifiRepository.getCurrentNetwork();
      final current = result.fold((_) => null, (network) => network);
      if (current?.ssid == ssid) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

  void _onDismissPasswordPrompt(
    DismissPasswordPromptEvent event,
    Emitter<WifiState> emit,
  ) {
    emit(state.copyWith(passwordPromptSsid: null, errorMessage: null));
  }

  Future<void> _onLoadSavedNetworks(
    LoadSavedNetworksEvent event,
    Emitter<WifiState> emit,
  ) async {
    final result = await _wifiRepository.getSavedNetworks();
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (saved) => emit(state.copyWith(savedNetworks: saved)),
    );
  }

  Future<void> _onForgetSavedNetwork(
    ForgetSavedNetworkEvent event,
    Emitter<WifiState> emit,
  ) async {
    final network = state.savedNetworks.firstWhere(
      (candidate) => candidate.ssid == event.ssid,
      orElse: () =>
          WifiNetwork(ssid: event.ssid, security: 'Saved', strength: '0%'),
    );

    final result = await _wifiRepository.forgetNetwork(network);
    final failure = _failureOf(result);
    if (failure != null) {
      emit(state.copyWith(errorMessage: failure.message));
      return;
    }

    await _refreshSaved(emit);
  }

  /// Reads the visible networks, the current association, and saved profiles.
  ///
  /// The read order keeps the page useful on partial failures: a scan failure is
  /// reported, while a missing current network simply means "disconnected".
  Future<void> _refresh(Emitter<WifiState> emit) async {
    final scanResult = await _wifiRepository.scanNetworks();
    final currentResult = await _wifiRepository.getCurrentNetwork();
    final savedResult = await _wifiRepository.getSavedNetworks();

    Failure? failure;
    var networks = const <WifiNetwork>[];
    WifiNetwork? current;
    var saved = const <WifiNetwork>[];

    scanResult.fold((value) => failure = value, (value) => networks = value);
    currentResult.fold(
      (value) => failure ??= value,
      (value) => current = value,
    );
    savedResult.fold((value) => failure ??= value, (value) => saved = value);

    if (failure != null) {
      emit(
        state.copyWith(
          status: WifiStatus.failure,
          errorMessage: failure!.message,
        ),
      );
      return;
    }

    final list = List.of(networks);
    if (current != null) {
      final index = list.indexWhere((network) => network.ssid == current!.ssid);
      if (index != -1) {
        list.insert(0, list.removeAt(index));
      }
    }

    emit(
      state.copyWith(
        status: WifiStatus.success,
        networks: list,
        savedNetworks: saved,
        connectedSsid: current?.ssid,
        passwordPromptSsid: null,
        errorMessage: null,
      ),
    );
  }

  /// Reloads only the saved profiles after a forget request.
  Future<void> _refreshSaved(Emitter<WifiState> emit) async {
    final result = await _wifiRepository.getSavedNetworks();
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (saved) => emit(state.copyWith(savedNetworks: saved)),
    );
  }

  /// Returns the page entity for [ssid], falling back to a placeholder.
  WifiNetwork _networkFor(String ssid) {
    for (final network in [...state.networks, ...state.savedNetworks]) {
      if (network.ssid == ssid) {
        return network;
      }
    }
    return WifiNetwork(ssid: ssid, security: '', strength: '0%');
  }

  /// Extracts the failure of a void result, or `null` on success.
  Failure? _failureOf(Either<Failure, void> result) {
    return result.fold((failure) => failure, (_) => null);
  }
}
