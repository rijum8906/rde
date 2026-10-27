import 'package:flutter/material.dart';
import 'package:rde_settings/features/wifi/presentation/widgets/wifi_network_card.dart';
import 'package:rde_settings/features/wifi/presentation/widgets/wifi_radio_card.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/wifi/data/datasources/dbus/network_manager_proxy.dart';
import 'package:rde_settings/features/wifi/data/datasources/dbus_wifi_datasource.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';
import 'package:rde_settings/features/wifi/domain/repositories/wifi_repository_impl.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_bloc.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_event.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_state.dart';
import 'package:rde_settings/features/wifi/presentation/widgets/wifi_error_banner.dart';
import 'package:rde_settings/features/wifi/presentation/widgets/wifi_header.dart';
import 'package:rde_settings/features/wifi/presentation/widgets/wifi_password_dialog.dart';
import 'package:rde_settings/features/wifi/presentation/widgets/wifi_saved_card.dart';

/// Sections of the Wi-Fi page.
enum WifiSection { available, saved }

/// Wi-Fi settings backed by NetworkManager.
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

/// Renders the state published by [WifiBloc].
///
/// Owns the local section selector and the password-dialog lifecycle. Both
/// are page concerns, not bloc concerns: the bloc does not know which tab the
/// user is on, and the dialog is a UI flow triggered by two different events.
class WifiView extends StatefulWidget {
  const WifiView({super.key});

  @override
  State<WifiView> createState() => _WifiViewState();
}

class _WifiViewState extends State<WifiView> {
  WifiSection _section = WifiSection.available;

  /// Connects the way NetworkManager prefers: saved profiles and open networks
  /// connect directly, and only a secured network without a profile asks for a
  /// password up front. A saved profile that fails prompts afterwards instead.
  void _handleConnect(WifiNetwork network, WifiState state) {
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

    _promptForPassword(network);
  }

  Future<void> _promptForPassword(WifiNetwork network) async {
    final password = await showWifiPasswordDialog(context, network);
    if (password == null || !mounted) {
      context.read<WifiBloc>().add(const DismissPasswordPromptEvent());
      return;
    }
    context.read<WifiBloc>().add(
      ConnectToNetworkEvent(network.ssid, password: password),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<WifiBloc, WifiState>(
      listenWhen: (previous, current) =>
          (current.passwordPromptSsid != null &&
              previous.passwordPromptSsid != current.passwordPromptSsid) ||
          (current.connectedNoticeSsid != null &&
              previous.connectedNoticeSsid != current.connectedNoticeSsid),
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
          _promptForPassword(network);
          return;
        }

        // Only a connection the user asked for is announced.
        final noticeSsid = state.connectedNoticeSsid;
        if (noticeSsid == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to $noticeSsid'),
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
                  WifiHeader(isLoading: isLoading),
                  const SizedBox(height: 20),
                  SegmentedButton<WifiSection>(
                    segments: const [
                      ButtonSegment(
                        value: WifiSection.available,
                        icon: Icon(Icons.wifi_find, size: 16),
                        label: Text('Available Networks'),
                      ),
                      ButtonSegment(
                        value: WifiSection.saved,
                        icon: Icon(Icons.bookmarks_outlined, size: 16),
                        label: Text('Saved Devices'),
                      ),
                    ],
                    selected: {_section},
                    onSelectionChanged: (selection) {
                      setState(() => _section = selection.first);
                      if (selection.first == WifiSection.saved) {
                        context.read<WifiBloc>().add(
                          const LoadSavedNetworksEvent(),
                        );
                      }
                    },
                    showSelectedIcon: false,
                  ),
                  const SizedBox(height: 20),
                  if (state.errorMessage != null) ...[
                    WifiErrorBanner(message: state.errorMessage!),
                    const SizedBox(height: 12),
                  ],

                  if (_section == WifiSection.available) ...[
                    WifiIdentityCard(),
                    const SizedBox(height: 16),
                    WifiNetworksCard(
                      state: state,
                      isLoading: isLoading,
                      onConnect: (network) => _handleConnect(network, state),
                      onDisconnect: (network) => context.read<WifiBloc>().add(
                        DisconnectFromNetworkEvent(network.ssid),
                      ),
                    ),
                  ] else
                    WifiSavedCard(
                      state: state,
                      onConnect: (network) => context.read<WifiBloc>().add(
                        ConnectToNetworkEvent(network.ssid),
                      ),
                      onDisconnect: (network) => context.read<WifiBloc>().add(
                        DisconnectFromNetworkEvent(network.ssid),
                      ),
                      onForget: (network) => context.read<WifiBloc>().add(
                        ForgetSavedNetworkEvent(network.ssid),
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
}
