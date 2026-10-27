import 'package:flutter/material.dart';

class BluetoothErrorBanner extends StatelessWidget {
  const BluetoothErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text('Error: $message', style: TextStyle(color: colorScheme.error));
  }
}
