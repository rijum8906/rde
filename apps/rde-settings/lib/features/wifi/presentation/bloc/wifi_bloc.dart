import 'dart:async';

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

  /// Live updates pushed by NetworkManager while the page is open.
  late final StreamSubscription<void> _changes;

  /// Collapses a burst of daemon signals into a single refresh.
  Timer? _changeDebounce;

  WifiBloc({required this._wifiRepository}) : super(WifiState.initial()) {
    on<WifiInitEvent>(_onInit);
    on<ScanNetworksEvent>(_onScanNetworks);
    on<ToggleWifiRadioEvent>(_onToggleWifiRadio);
    on<ConnectToNetworkEvent>(_onConnectToNetwork);
    on<DisconnectFromNetworkEvent>(_onDisconnectFromNetwork);
    on<DismissPasswordPromptEvent>(_onDismissPasswordPrompt);
    on<LoadSavedNetworksEvent>(_onLoadSavedNetworks);
    on<ForgetSavedNetworkEvent>(_onForgetSavedNetwork);
    on<WifiServiceChangedEvent>(_onServiceChanged);

    // NetworkManager owns the radio, the association, the scan results, and the
    // saved profiles, and any client can change them. Listening to its signals
    // keeps the page showing the daemon's state instead of a snapshot taken
    // when it was opened.
    _changes = _wifiRepository.watchChanges().listen(
      (_) => add(const WifiServiceChangedEvent()),
      onError: (Object _) {},
    );
  }

  @override
  Future<void> close() async {
    _changeDebounce?.cancel();
    await _changes.cancel();
    return super.close();
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
          connectedNoticeSsid: null,
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

  /// Refreshes the page after a daemon signal.
  ///
  /// One daemon action produces several signals — a scan alone adds an access
  /// point per network — so the refresh waits for the burst to settle. The page
  /// keeps showing its current content until then, and a connect request in
  /// flight is left alone because it refreshes when it finishes.
  void _onServiceChanged(
    WifiServiceChangedEvent event,
    Emitter<WifiState> emit,
  ) {
    _changeDebounce?.cancel();
    _changeDebounce = Timer(const Duration(milliseconds: 350), () {
      if (state.connectingSsid != null) {
        return;
      }
      add(const ScanNetworksEvent());
    });
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
          connectedNoticeSsid: null,
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
        // Only a connection the user asked for raises a notification.
        connectedNoticeSsid: event.ssid,
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

  /// Disconnects the active network.
  ///
  /// The row that asked shows the spinner through `connectingSsid`, and the
  /// daemon is read back afterwards, so the association the page shows comes
  /// from NetworkManager instead of an optimistic guess.
  Future<void> _onDisconnectFromNetwork(
    DisconnectFromNetworkEvent event,
    Emitter<WifiState> emit,
  ) async {
    if (state.connectingSsid != null) {
      return;
    }

    emit(state.copyWith(connectingSsid: event.ssid, errorMessage: null));

    final result = await _wifiRepository.disconnectFromNetwork(
      _networkFor(event.ssid),
    );
    final failure = _failureOf(result);
    if (failure != null) {
      emit(state.copyWith(connectingSsid: null, errorMessage: failure.message));
      return;
    }

    emit(state.copyWith(connectingSsid: null));
    await _refresh(emit);
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
    // Step 1: Re-read the radio, because another client can turn it off while
    // the page is open. A failed read keeps the state the page already shows.
    var enabled = state.isWifiEnabled;
    final enabledResult = await _wifiRepository.isWifiEnabled();
    enabledResult.fold((_) {}, (value) => enabled = value);

    if (!enabled) {
      emit(
        state.copyWith(
          status: WifiStatus.success,
          isWifiEnabled: false,
          networks: const [],
          savedNetworks: const [],
          connectedSsid: null,
          connectedNoticeSsid: null,
          errorMessage: null,
        ),
      );
      return;
    }

    // Step 2: Read the visible networks, the current association, and the
    // saved profiles.
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
        isWifiEnabled: enabled,
        networks: list,
        savedNetworks: saved,
        connectedSsid: current?.ssid,
        passwordPromptSsid: null,
        errorMessage: null,
        // The state read back from the daemon never notifies on its own: a
        // network that was already connected stays quiet.
        connectedNoticeSsid: null,
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
