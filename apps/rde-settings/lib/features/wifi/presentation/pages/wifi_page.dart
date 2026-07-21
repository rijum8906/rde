import 'package:flutter/material.dart';
import 'package:rde_settings/features/wifi/data/datasources/dbus/network_manager_proxy.dart';
import 'package:rde_settings/features/wifi/data/datasources/dbus_wifi_datasource.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';
import 'package:rde_settings/features/wifi/domain/repositories/wifi_repository.dart';
import 'package:rde_settings/features/wifi/domain/repositories/wifi_repository_impl.dart';

class WifiPage extends StatefulWidget {
  const WifiPage({super.key});

  @override
  State<WifiPage> createState() => _WifiPageState();
}

class _WifiPageState extends State<WifiPage> {
  late final WifiRepository _wifiRepository;
  bool _isWifiEnabled = true;
  List<WifiNetwork> _networks = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _connectedSsid = 'RDE-Net';
  String? _connectingSsid;

  @override
  void initState() {
    super.initState();
    final proxy = NetworkManagerProxy();
    final datasource = DbusWifiDatasource(proxy);
    _wifiRepository = WifiRepositoryImpl(datasource);

    if (_isWifiEnabled) {
      _scanNetworks();
    }
  }

  Future<void> _scanNetworks() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await _wifiRepository.scanNetworks();

    if (mounted) {
      res.fold(
        (failure) {
          setState(() {
            _isLoading = false;
            _errorMessage = failure.message;
          });
        },
        (networks) {
          setState(() {
            _isLoading = false;
            _networks = networks;
            // Ensure the connected network is always at the top
            if (_connectedSsid != null) {
              final connectedIndex = _networks.indexWhere(
                (n) => n.ssid == _connectedSsid,
              );
              if (connectedIndex != -1) {
                final connectedNet = _networks.removeAt(connectedIndex);
                _networks.insert(0, connectedNet);
              }
            }
          });
        },
      );
    }
  }

  void _handleConnect(WifiNetwork network) {
    if (network.security == 'Open') {
      _connectDirectly(network.ssid);
    } else {
      _showPasswordDialog(network);
    }
  }

  Future<void> _connectDirectly(String ssid) async {
    setState(() {
      _connectingSsid = ssid;
    });

    // Simulate connecting delay
    await Future.delayed(const Duration(milliseconds: 1200));

    if (mounted) {
      setState(() {
        _connectedSsid = ssid;
        _connectingSsid = null;
        // Shift connected to top
        final connectedIndex = _networks.indexWhere((n) => n.ssid == ssid);
        if (connectedIndex != -1) {
          final connectedNet = _networks.removeAt(connectedIndex);
          _networks.insert(0, connectedNet);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to $ssid'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPasswordDialog(WifiNetwork network) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
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
                _connectDirectly(network.ssid);
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

    return Scaffold(
      body: SingleChildScrollView(
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
                if (_isWifiEnabled)
                  IconButton.filledTonal(
                    onPressed: _isLoading ? null : _scanNetworks,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                                color: _isWifiEnabled
                                    ? colorScheme.primaryContainer
                                    : colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                _isWifiEnabled ? Icons.wifi : Icons.wifi_off,
                                color: _isWifiEnabled
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
                                  _isWifiEnabled
                                      ? (_connectedSsid != null
                                            ? 'Connected to $_connectedSsid'
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
                          value: _isWifiEnabled,
                          onChanged: (val) {
                            setState(() {
                              _isWifiEnabled = val;
                              if (val) {
                                _scanNetworks();
                              } else {
                                _networks.clear();
                                _connectedSsid = null;
                              }
                            });
                          },
                        ),
                      ],
                    ),

                    // Wi-Fi Scan List
                    if (_isWifiEnabled) ...[
                      const Divider(height: 32),
                      if (_isLoading && _networks.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 36.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Text(
                            'Error: $_errorMessage',
                            style: TextStyle(color: colorScheme.error),
                          ),
                        )
                      else ...[
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _networks.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final network = _networks[index];
                            final isConnected = _connectedSsid == network.ssid;
                            final isConnecting =
                                _connectingSsid == network.ssid;

                            return _buildNetworkTile(
                              context: context,
                              network: network,
                              isConnected: isConnected,
                              isConnecting: isConnecting,
                            );
                          },
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
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
              onPressed: () => _handleConnect(network),
              child: const Text('Connect'),
            ),
        ],
      ),
    );
  }
}
