import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_device.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_event.dart';
import 'package:rde_settings/features/bluetooth/presentation/widgets/bluetooth_device_icon.dart';
import 'package:core/core.dart';

class BluetoothDeviceTile extends StatelessWidget {
  const BluetoothDeviceTile({super.key, required this.device});

  final BluetoothDevice device;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isBusy = context.select<BluetoothBloc, bool>(
      (bloc) => bloc.state.busyAddress == device.address,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      child: Row(
        children: [
          _DeviceAvatar(device: device),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: device.connected
                        ? FontWeight.bold
                        : FontWeight.w500,
                  ),
                ),
                _RichSubtitle(device: device),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isBusy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              child: RdeLoadingIndicator(size: 20),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (device.connected)
                  TextButton(
                    onPressed: () => context.read<BluetoothBloc>().add(
                      DisconnectDeviceEvent(device.address),
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      foregroundColor: colorScheme.error,
                      overlayColor: colorScheme.error.withValues(alpha: 0.08),
                    ),
                    child: const Text('Disconnect'),
                  )
                else
                  FilledButton.tonal(
                    onPressed: () => context.read<BluetoothBloc>().add(
                      ConnectDeviceEvent(device.address),
                    ),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: Text(device.paired ? 'Connect' : 'Connect anyway'),
                  ),
                // Shared menu: same items in both states, with "Connect"/"Disconnect"
                // handled by the primary button above.
                PopupMenuButton<String>(
                  tooltip: 'More actions',
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) {
                    final bloc = context.read<BluetoothBloc>();
                    switch (value) {
                      case 'pair':
                        bloc.add(PairDeviceEvent(device.address));
                      case 'trust':
                        bloc.add(SetTrustedDeviceEvent(device.address, true));
                      case 'untrust':
                        bloc.add(SetTrustedDeviceEvent(device.address, false));
                      case 'forget':
                        bloc.add(ForgetDeviceEvent(device.address));
                    }
                  },
                  itemBuilder: (context) => [
                    if (!device.paired)
                      const PopupMenuItem(value: 'pair', child: Text('Pair')),
                    if (device.trusted)
                      const PopupMenuItem(
                        value: 'untrust',
                        child: Text('Remove trust'),
                      )
                    else
                      const PopupMenuItem(
                        value: 'trust',
                        child: Text('Trust device'),
                      ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'forget', child: Text('Forget')),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Rounded square holding the device-class icon. Tinted when connected.
class _DeviceAvatar extends StatelessWidget {
  const _DeviceAvatar({required this.device});

  final BluetoothDevice device;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final connected = device.connected;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: connected
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: BluetoothDeviceIcon(
          icon: device.icon,
          size: 20,
          color: connected
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _RichSubtitle extends StatelessWidget {
  const _RichSubtitle({required this.device});

  final BluetoothDevice device;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final value = theme.textTheme.bodySmall!.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w600,
      fontSize: (theme.textTheme.bodySmall!.fontSize ?? 12) + 1,
    );

    final spans = <InlineSpan>[];
    void add(String text, TextStyle style) {
      if (spans.isNotEmpty) spans.add(TextSpan(text: '  •  ', style: muted));
      spans.add(TextSpan(text: text, style: style));
    }

    if (device.batteryPercentage != null) {
      add('${device.batteryPercentage}%', value);
    }
    if (device.rssi != null) {
      add('${device.rssi} dBm', value);
    }

    // Nothing to show: hide the subtitle line rather than render an empty
    // Text that takes up vertical space and makes the row look taller than
    // its siblings.
    if (spans.isEmpty) return const SizedBox.shrink();

    return Text.rich(
      TextSpan(children: spans),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}
