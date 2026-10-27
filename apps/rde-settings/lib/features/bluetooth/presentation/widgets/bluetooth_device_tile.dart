import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/core/widgets/loading_indicator.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_device.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_event.dart';
import 'package:rde_settings/features/bluetooth/presentation/utils/bluetooth_device_helpers.dart';
import 'package:rde_settings/features/bluetooth/presentation/widgets/bluetooth_device_icon.dart';

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
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    BluetoothDeviceIcon(
                      icon: device.icon,
                      color: device.connected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 16),
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
                                  : FontWeight.normal,
                            ),
                          ),
                          Text(
                            subtitleForDevice(device),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (device.connected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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
                ),
            ],
          ),
          if (isBusy)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: RdeLoadingIndicator(size: 20),
            )
          else
            _DeviceActions(device: device),
        ],
      ),
    );
  }
}

class _DeviceActions extends StatelessWidget {
  const _DeviceActions({required this.device});

  final BluetoothDevice device;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<BluetoothBloc>();

    return Row(
      children: [
        if (device.connected)
          TextButton(
            onPressed: () => bloc.add(DisconnectDeviceEvent(device.address)),
            child: const Text('Disconnect'),
          )
        else
          TextButton(
            onPressed: () => bloc.add(ConnectDeviceEvent(device.address)),
            child: Text(device.paired ? 'Connect' : 'Connect anyway'),
          ),
        if (!device.paired)
          TextButton(
            onPressed: () => bloc.add(PairDeviceEvent(device.address)),
            child: const Text('Pair'),
          ),
        PopupMenuButton<String>(
          tooltip: 'More actions',
          onSelected: (value) {
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
              const PopupMenuItem(value: 'untrust', child: Text('Remove trust'))
            else
              const PopupMenuItem(value: 'trust', child: Text('Trust device')),
            const PopupMenuItem(value: 'forget', child: Text('Forget')),
          ],
        ),
      ],
    );
  }
}
