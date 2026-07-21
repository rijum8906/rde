import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/wifi/data/datasources/dbus/network_manager_proxy.dart';
import 'package:rde_settings/features/wifi/data/datasources/dbus_wifi_datasource.dart';
import 'package:rde_settings/features/wifi/domain/repositories/wifi_repository_impl.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_bloc.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_event.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_state.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';

class WifiPage extends StatelessWidget {
  const WifiPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Instantiate repository dependencies locally
    final proxy = NetworkManagerProxy();
    final datasource = DbusWifiDatasource(proxy);
    final repository = WifiRepositoryImpl(datasource);

    return BlocProvider(
      create: (context) =>
          WifiBloc(wifiRepository: repository)..add(const WifiInitEvent()),
      child: const WifiView(),
    );
  }
}

class WifiView extends StatelessWidget {
  const WifiView({super.key});

  void _handleConnect(BuildContext context, WifiNetwork network) {
    if (network.security == 'Open') {
      context.read<WifiBloc>().add(ConnectToNetworkEvent(network.ssid));
    } else {
      _showPasswordDialog(context, network);
    }
  }

  void _showPasswordDialog(BuildContext parentContext, WifiNetwork network) {
    final passwordController = TextEditingController();
    showDialog(
      context: parentContext,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text('Connect to ${network.ssid}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Security: ${network.security}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter network security key',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                parentContext.read<WifiBloc>().add(
                  ConnectToNetworkEvent(network.ssid),
                );
              },
              child: const Text('Connect'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocListener<WifiBloc, WifiState>(
      listenWhen: (previous, current) =>
          previous.connectedSsid != current.connectedSsid &&
          current.connectedSsid != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${state.connectedSsid}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Scaffold(
        body: BlocBuilder<WifiBloc, WifiState>(
          builder: (context, state) {
            final isLoading = state.status == WifiStatus.loading;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wi-Fi Settings',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manage wireless connections and networks',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (state.isWifiEnabled)
                        IconButton.filledTonal(
                          onPressed: isLoading
                              ? null
                              : () => context.read<WifiBloc>().add(
                                  const ScanNetworksEvent(),
                                ),
                          icon: isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh),
                          tooltip: 'Rescan Networks',
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Card Panel
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          // Wi-Fi Master Enable Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: state.isWifiEnabled
                                          ? colorScheme.primaryContainer
                                          : colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      state.isWifiEnabled
                                          ? Icons.wifi
                                          : Icons.wifi_off,
                                      color: state.isWifiEnabled
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Wi-Fi Radio',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      Text(
                                        state.isWifiEnabled
                                            ? (state.connectedSsid != null
                                                  ? 'Connected to ${state.connectedSsid}'
                                                  : 'Ready to connect')
                                            : 'Radio Disabled',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Switch(
                                value: state.isWifiEnabled,
                                onChanged: (val) {
                                  context.read<WifiBloc>().add(
                                    ToggleWifiRadioEvent(val),
                                  );
                                },
                              ),
                            ],
                          ),

                          // Wi-Fi Scan List
                          if (state.isWifiEnabled) ...[
                            const Divider(height: 32),
                            if (isLoading && state.networks.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 36.0),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (state.errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24.0,
                                ),
                                child: Text(
                                  'Error: ${state.errorMessage}',
                                  style: TextStyle(color: colorScheme.error),
                                ),
                              )
                            else ...[
                              Column(
                                children: List.generate(state.networks.length, (
                                  index,
                                ) {
                                  final network = state.networks[index];
                                  final isConnected =
                                      state.connectedSsid == network.ssid;
                                  final isConnecting =
                                      state.connectingSsid == network.ssid;

                                  return Column(
                                    children: [
                                      if (index > 0) const Divider(),
                                      _buildNetworkTile(
                                        context: context,
                                        network: network,
                                        isConnected: isConnected,
                                        isConnecting: isConnecting,
                                      ),
                                    ],
                                  );
                                }),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNetworkTile({
    required BuildContext context,
    required WifiNetwork network,
    required bool isConnected,
    required bool isConnecting,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    IconData signalIcon = Icons.wifi_lock;
    if (network.security == 'Open') {
      signalIcon = Icons.wifi;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                signalIcon,
                size: 20,
                color: isConnected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    network.ssid,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: isConnected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  Text(
                    'Security: ${network.security} • Signal: ${network.strength}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Connected',
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            )
          else if (isConnecting)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            TextButton(
              onPressed: () => _handleConnect(context, network),
              child: const Text('Connect'),
            ),
        ],
      ),
    );
  }
}
