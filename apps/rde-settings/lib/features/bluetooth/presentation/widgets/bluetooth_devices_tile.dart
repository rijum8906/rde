import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_device.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_event.dart';
import 'package:rde_settings/features/bluetooth/presentation/utils/bluetooth_device_helpers.dart';
import 'package:rde_settings/features/bluetooth/presentation/widgets/bluetooth_device_icon.dart';
import 'package:rde_settings/core/widgets/loading_indicator.dart';

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
                Text(
                  subtitleForDevice(device),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isBusy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              child: RdeLoadingIndicator(size: 20),
            )
          else if (device.connected)
            _ConnectedBadge()
          else
            _DeviceActions(device: device),
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

/// "Connected" pill shown in the trailing slot when the device is active.
class _ConnectedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 14, color: colorScheme.onPrimary),
          const SizedBox(width: 4),
          Text(
            'Connected',
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// The compact trailing action area: one filled-tonal button for the primary
/// action, plus a menu for pair/trust/forget.
class _DeviceActions extends StatelessWidget {
  const _DeviceActions({required this.device});

  final BluetoothDevice device;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<BluetoothBloc>();
    final isPaired = device.paired;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.tonal(
          onPressed: () => bloc.add(ConnectDeviceEvent(device.address)),
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            textStyle: const TextStyle(fontSize: 12),
          ),
          child: Text(isPaired ? 'Connect' : 'Connect anyway'),
        ),
        PopupMenuButton<String>(
          tooltip: 'More actions',
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: (value) {
            switch (value) {
              case 'pair':
                bloc.add(PairDeviceEvent(device.address));
              case 'disconnect':
                bloc.add(DisconnectDeviceEvent(device.address));
              case 'trust':
                bloc.add(SetTrustedDeviceEvent(device.address, true));
              case 'untrust':
                bloc.add(SetTrustedDeviceEvent(device.address, false));
              case 'forget':
                bloc.add(ForgetDeviceEvent(device.address));
            }
          },
          itemBuilder: (context) => [
            if (!isPaired)
              const PopupMenuItem(value: 'pair', child: Text('Pair')),
            if (device.trusted)
              const PopupMenuItem(value: 'untrust', child: Text('Remove trust'))
            else
              const PopupMenuItem(value: 'trust', child: Text('Trust device')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'forget', child: Text('Forget')),
          ],
        ),
      ],
    );
  }
}
