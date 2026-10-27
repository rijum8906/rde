import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/wifi/data/datasources/dbus/network_manager_proxy.dart';
import 'package:rde_settings/features/wifi/data/datasources/dbus_wifi_datasource.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';
import 'package:rde_settings/features/wifi/domain/repositories/wifi_repository_impl.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_bloc.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_event.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_state.dart';

/// Sections of the Wi-Fi page.
enum _WifiSection { available, saved }

class WifiPage extends StatelessWidget {
  const WifiPage({super.key});

  @override
  Widget build(BuildContext context) {
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

class WifiView extends StatefulWidget {
  const WifiView({super.key});

  @override
  State<WifiView> createState() => _WifiViewState();
}

class _WifiViewState extends State<WifiView> {
  _WifiSection _section = _WifiSection.available;

  /// Connects the way NetworkManager prefers: saved profiles and open networks
  /// connect directly, and only a secured network without a profile asks for a
  /// password up front. A saved profile that fails prompts afterwards instead.
  void _handleConnect(
    BuildContext context,
    WifiNetwork network,
    WifiState state,
  ) {
    final isSaved = state.savedNetworks.any(
      (candidate) => candidate.ssid == network.ssid,
    );

    if (isSaved) {
      context.read<WifiBloc>().add(
        ConnectToNetworkEvent(
          network.ssid,
          promptOnFailure: network.security != 'Open',
        ),
      );
      return;
    }

    if (network.security == 'Open') {
      context.read<WifiBloc>().add(ConnectToNetworkEvent(network.ssid));
      return;
    }

    _showPasswordDialog(context, network);
  }

  void _showPasswordDialog(BuildContext parentContext, WifiNetwork network) {
    final passwordController = TextEditingController();

    showDialog<void>(
      context: parentContext,
      barrierDismissible: false,
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
                autofocus: true,
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
              onPressed: () {
                Navigator.of(context).pop();
                parentContext.read<WifiBloc>().add(
                  const DismissPasswordPromptEvent(),
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final password = passwordController.text;
                Navigator.of(context).pop();
                parentContext.read<WifiBloc>().add(
                  ConnectToNetworkEvent(network.ssid, password: password),
                );
              },
              child: const Text('Connect'),
            ),
          ],
        );
      },
    ).whenComplete(passwordController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocListener<WifiBloc, WifiState>(
      listenWhen: (previous, current) =>
          (current.passwordPromptSsid != null &&
              previous.passwordPromptSsid != current.passwordPromptSsid) ||
          (current.connectedSsid != null &&
              previous.connectedSsid != current.connectedSsid),
      listener: (context, state) {
        // A saved profile failed to activate: ask for a password now.
        final promptSsid = state.passwordPromptSsid;
        if (promptSsid != null) {
          final network = state.networks.firstWhere(
            (candidate) => candidate.ssid == promptSsid,
            orElse: () => WifiNetwork(
              ssid: promptSsid,
              security: 'Secured',
              strength: '0%',
            ),
          );
          _showPasswordDialog(context, network);
          return;
        }

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
                  const SizedBox(height: 20),

                  SegmentedButton<_WifiSection>(
                    segments: const [
                      ButtonSegment(
                        value: _WifiSection.available,
                        icon: Icon(Icons.wifi_find, size: 16),
                        label: Text('Available Networks'),
                      ),
                      ButtonSegment(
                        value: _WifiSection.saved,
                        icon: Icon(Icons.bookmarks_outlined, size: 16),
                        label: Text('Saved Devices'),
                      ),
                    ],
                    selected: {_section},
                    onSelectionChanged: (selection) {
                      setState(() => _section = selection.first);
                      if (selection.first == _WifiSection.saved) {
                        context.read<WifiBloc>().add(
                          const LoadSavedNetworksEvent(),
                        );
                      }
                    },
                    showSelectedIcon: false,
                  ),
                  const SizedBox(height: 20),

                  if (state.errorMessage != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Error: ${state.errorMessage}',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  ],

                  if (_section == _WifiSection.available)
                    _buildAvailableCard(context, state, isLoading)
                  else
                    _buildSavedCard(context, state),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Radio switch followed by the scanned access points.
  Widget _buildAvailableCard(
    BuildContext context,
    WifiState state,
    bool isLoading,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
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
                        state.isWifiEnabled ? Icons.wifi : Icons.wifi_off,
                        color: state.isWifiEnabled
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wi-Fi Radio',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          state.isWifiEnabled
                              ? (state.connectedSsid != null
                                    ? 'Connected to ${state.connectedSsid}'
                                    : 'Ready to connect')
                              : 'Radio Disabled',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: state.isWifiEnabled,
                  onChanged: (value) {
                    context.read<WifiBloc>().add(ToggleWifiRadioEvent(value));
                  },
                ),
              ],
            ),

            if (state.isWifiEnabled) ...[
              const Divider(height: 32),
              if (isLoading && state.networks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.networks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Text(
                    'No networks found. Move closer to a router or rescan.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Column(
                  children: List.generate(state.networks.length, (index) {
                    final network = state.networks[index];
                    return Column(
                      children: [
                        if (index > 0) const Divider(),
                        _buildNetworkTile(
                          context: context,
                          state: state,
                          network: network,
                          isConnected: state.connectedSsid == network.ssid,
                          isConnecting: state.connectingSsid == network.ssid,
                          isSaved: state.savedNetworks.any(
                            (saved) => saved.ssid == network.ssid,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// The second page: profiles NetworkManager stores and reconnects to.
  Widget _buildSavedCard(BuildContext context, WifiState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history_toggle_off_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Saved Devices & Profiles',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Profiles NetworkManager reconnects to automatically. '
              'Connect uses the stored credentials.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (state.savedNetworks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Text(
                  'No saved devices yet. Join a network once and it appears '
                  'here.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Column(
                children: List.generate(state.savedNetworks.length, (index) {
                  final network = state.savedNetworks[index];
                  return Column(
                    children: [
                      if (index > 0) const Divider(),
                      _buildSavedTile(
                        context: context,
                        network: network,
                        isConnected: state.connectedSsid == network.ssid,
                        isConnecting: state.connectingSsid == network.ssid,
                      ),
                    ],
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkTile({
    required BuildContext context,
    required WifiState state,
    required WifiNetwork network,
    required bool isConnected,
    required bool isConnecting,
    required bool isSaved,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final signalIcon = network.security == 'Open'
        ? Icons.wifi
        : Icons.wifi_lock;

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
                    'Security: ${network.security} • Signal: '
                    '${network.strength}${isSaved ? ' • Saved' : ''}',
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
              onPressed: () => _handleConnect(context, network, state),
              child: const Text('Connect'),
            ),
        ],
      ),
    );
  }

  Widget _buildSavedTile({
    required BuildContext context,
    required WifiNetwork network,
    required bool isConnected,
    required bool isConnecting,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.bookmark_added_outlined,
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
                    isConnected ? 'Currently Connected' : 'Saved Profile',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              if (!isConnected) ...[
                if (isConnecting)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else
                  TextButton(
                    onPressed: () {
                      context.read<WifiBloc>().add(
                        ConnectToNetworkEvent(network.ssid),
                      );
                    },
                    child: const Text('Connect'),
                  ),
                const SizedBox(width: 8),
              ],
              IconButton(
                onPressed: () {
                  context.read<WifiBloc>().add(
                    ForgetSavedNetworkEvent(network.ssid),
                  );
                },
                icon: Icon(
                  Icons.delete_outline,
                  color: colorScheme.error.withValues(alpha: 0.8),
                ),
                tooltip: 'Forget Profile',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
