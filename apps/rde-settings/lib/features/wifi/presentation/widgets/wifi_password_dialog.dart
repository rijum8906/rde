import 'package:flutter/material.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';

/// Asks for the password of [network] and returns it, or `null` if cancelled.
Future<String?> showWifiPasswordDialog(
  BuildContext context,
  WifiNetwork network,
) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _WifiPasswordDialog(network: network),
  );
}

class _WifiPasswordDialog extends StatefulWidget {
  const _WifiPasswordDialog({required this.network});

  final WifiNetwork network;

  @override
  State<_WifiPasswordDialog> createState() => _WifiPasswordDialogState();
}

class _WifiPasswordDialogState extends State<_WifiPasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Connect to ${widget.network.ssid}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Security: ${widget.network.security}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Connect'),
        ),
      ],
    );
  }
}
