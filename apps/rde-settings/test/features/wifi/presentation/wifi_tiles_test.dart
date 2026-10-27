import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_state.dart';
import 'package:rde_settings/features/wifi/presentation/widgets/wifi_network_tile.dart';
import 'package:rde_settings/features/wifi/presentation/widgets/wifi_saved_tile.dart';

final _network = WifiNetwork(ssid: 'Home', security: 'WPA2', strength: '80%');

void main() {
  testWidgets('a connected network row offers a disconnect action', (
    tester,
  ) async {
    var disconnects = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WifiNetworkTile(
            state: WifiState.initial(),
            network: _network,
            isConnected: true,
            isConnecting: false,
            isSaved: true,
            onConnect: () {},
            onDisconnect: () => disconnects += 1,
          ),
        ),
      ),
    );

    expect(find.widgetWithText(TextButton, 'Disconnect'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Connect'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, 'Disconnect'));
    expect(disconnects, 1);
  });

  testWidgets('a connected saved profile offers a disconnect action', (
    tester,
  ) async {
    var disconnects = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WifiSavedTile(
            network: _network,
            isConnected: true,
            isConnecting: false,
            onConnect: () {},
            onDisconnect: () => disconnects += 1,
            onForget: () {},
          ),
        ),
      ),
    );

    expect(find.text('Currently Connected'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Disconnect'));
    expect(disconnects, 1);
  });

  testWidgets('an available network row offers Connect, not Disconnect', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WifiNetworkTile(
            state: WifiState.initial(),
            network: _network,
            isConnected: false,
            isConnecting: false,
            isSaved: false,
            onConnect: () {},
            onDisconnect: () {},
          ),
        ),
      ),
    );

    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Disconnect'), findsNothing);
  });
}
