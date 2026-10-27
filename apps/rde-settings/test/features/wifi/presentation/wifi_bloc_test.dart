import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';
import 'package:rde_settings/features/wifi/domain/repositories/wifi_repository.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_bloc.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_event.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_state.dart';

/// In-memory repository that records the connect calls the page makes.
class _FakeWifiRepository implements WifiRepository {
  bool failConnect = false;
  String? currentSsid;
  String? lastPassword;
  int disconnectCalls = 0;

  /// Stands in for the NetworkManager signal stream.
  final StreamController<void> changes = StreamController<void>.broadcast();

  /// Pretends the daemon pushed a change the page has to show.
  void notifyChange() => changes.add(null);

  final List<WifiNetwork> networks = [
    WifiNetwork(ssid: 'Home', security: 'WPA2', strength: '80%'),
    WifiNetwork(ssid: 'Cafe', security: 'Open', strength: '40%'),
  ];

  @override
  Future<Either<Failure, WifiNetwork>> connectToNetwork(
    WifiNetwork network, {
    String? password,
  }) async {
    lastPassword = password;
    if (failConnect) {
      return Left(Failure('The saved password is outdated.'));
    }
    currentSsid = network.ssid;
    return Right(network);
  }

  @override
  Future<Either<Failure, void>> disconnectFromNetwork(
    WifiNetwork network,
  ) async {
    disconnectCalls += 1;
    currentSsid = null;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> forgetNetwork(WifiNetwork network) async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, WifiNetwork?>> getCurrentNetwork() async {
    if (currentSsid == null) {
      return const Right(null);
    }
    return Right(
      networks.firstWhere(
        (network) => network.ssid == currentSsid,
        orElse: () =>
            WifiNetwork(ssid: currentSsid!, security: 'Saved', strength: '0%'),
      ),
    );
  }

  @override
  Future<Either<Failure, int>> getNetworkPriority(WifiNetwork network) async {
    return const Right(0);
  }

  @override
  Future<Either<Failure, List<WifiNetwork>>> getSavedNetworks() async {
    return const Right([]);
  }

  @override
  Future<Either<Failure, List<WifiNetwork>>> scanNetworks() async {
    return Right(networks);
  }

  @override
  Future<Either<Failure, void>> setNetworkPriority(
    WifiNetwork network,
    int priority,
  ) async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, bool>> isWifiEnabled() async {
    return const Right(true);
  }

  @override
  Future<Either<Failure, void>> setWifiEnabled(bool enabled) async {
    return const Right(null);
  }

  @override
  Stream<void> watchChanges() => changes.stream;
}

void main() {
  test(
    'saved-profile failure asks for a password instead of erroring',
    () async {
      final repository = _FakeWifiRepository()..failConnect = true;
      final bloc = WifiBloc(wifiRepository: repository);

      final prompted = bloc.stream.firstWhere(
        (state) => state.passwordPromptSsid == 'Home',
      );
      bloc.add(const ConnectToNetworkEvent('Home', promptOnFailure: true));
      final state = await prompted;

      expect(state.passwordPromptSsid, 'Home');
      expect(state.errorMessage, isNull);
      expect(repository.lastPassword, isNull);

      await bloc.close();
    },
  );

  test('a password attempt that fails reports the error', () async {
    final repository = _FakeWifiRepository()..failConnect = true;
    final bloc = WifiBloc(wifiRepository: repository);

    final failed = bloc.stream.firstWhere(
      (state) => state.errorMessage != null,
    );
    bloc.add(
      const ConnectToNetworkEvent(
        'Home',
        password: 'wrong',
        promptOnFailure: true,
      ),
    );
    final state = await failed;

    expect(state.passwordPromptSsid, isNull);
    expect(state.errorMessage, 'The saved password is outdated.');
    expect(repository.lastPassword, 'wrong');

    await bloc.close();
  });

  test('a successful connection raises the connect notice', () async {
    final repository = _FakeWifiRepository();
    final bloc = WifiBloc(wifiRepository: repository);

    bloc.add(const WifiInitEvent());
    await bloc.stream.firstWhere((state) => state.status == WifiStatus.success);

    final connected = bloc.stream.firstWhere(
      (state) => state.connectedSsid == 'Home',
    );
    bloc.add(const ConnectToNetworkEvent('Home'));
    final state = await connected;

    expect(state.connectedNoticeSsid, 'Home');

    await bloc.close();
  });

  test('opening the page on a connected network raises no notice', () async {
    final repository = _FakeWifiRepository()..currentSsid = 'Home';
    final bloc = WifiBloc(wifiRepository: repository);

    bloc.add(const WifiInitEvent());
    final state = await bloc.stream.firstWhere(
      (candidate) => candidate.status == WifiStatus.success,
    );

    expect(state.connectedSsid, 'Home');
    expect(state.connectedNoticeSsid, isNull);

    await bloc.close();
  });

  test('a NetworkManager signal refreshes the page without a notice', () async {
    final repository = _FakeWifiRepository();
    final bloc = WifiBloc(wifiRepository: repository);

    bloc.add(const WifiInitEvent());
    await bloc.stream.firstWhere((state) => state.status == WifiStatus.success);

    // Another client joins the network, then the daemon reports it.
    repository.currentSsid = 'Cafe';
    final refreshed = bloc.stream.firstWhere(
      (state) => state.connectedSsid == 'Cafe',
    );
    repository.notifyChange();
    final state = await refreshed;

    expect(state.connectedNoticeSsid, isNull);

    await bloc.close();
  });

  test('a successful connection becomes the current network', () async {
    final repository = _FakeWifiRepository();
    final bloc = WifiBloc(wifiRepository: repository);

    bloc.add(const WifiInitEvent());
    await bloc.stream.firstWhere((state) => state.status == WifiStatus.success);

    final connected = bloc.stream.firstWhere(
      (state) => state.connectedSsid == 'Home',
    );
    bloc.add(const ConnectToNetworkEvent('Home'));
    final state = await connected;

    expect(state.connectingSsid, isNull);
    expect(state.errorMessage, isNull);
    expect(state.savedNetworks, isEmpty);

    await bloc.close();
  });

  test('disconnecting clears the current network', () async {
    final repository = _FakeWifiRepository()..currentSsid = 'Home';
    final bloc = WifiBloc(wifiRepository: repository);

    bloc.add(const WifiInitEvent());
    await bloc.stream.firstWhere((state) => state.status == WifiStatus.success);
    expect(bloc.state.connectedSsid, 'Home');

    final disconnected = bloc.stream.firstWhere(
      (state) => state.connectedSsid == null && state.isWifiEnabled,
    );
    bloc.add(const DisconnectFromNetworkEvent('Home'));
    final state = await disconnected;

    expect(repository.disconnectCalls, 1);
    expect(state.connectingSsid, isNull);
    expect(state.errorMessage, isNull);

    await bloc.close();
  });
}
