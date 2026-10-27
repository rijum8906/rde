import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/core/widgets/loading_indicator.dart';
import 'package:rde_settings/features/bluetooth/data/datasources/dbus/bluez_proxy.dart';
import 'package:rde_settings/features/bluetooth/data/datasources/dbus_bluetooth_datasource.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_device.dart';
import 'package:rde_settings/features/bluetooth/domain/repositories/bluetooth_repository_impl.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_event.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_state.dart';

class BluetoothPage extends StatelessWidget {
  const BluetoothPage({super.key});

  @override
  Widget build(BuildContext context) {
    // The page is a BlueZ client: bluetoothd owns the adapter and the device
    // tree, so every read and mutation goes through org.bluez.
    final proxy = BluezProxy();
    final datasource = DbusBluetoothDatasource(proxy);
    final repository = BluetoothRepositoryImpl(datasource);

    return BlocProvider(
      create: (context) =>
          BluetoothBloc(bluetoothRepository: repository)
            ..add(const BluetoothInitEvent()),
      child: const BluetoothView(),
    );
  }
}

class BluetoothView extends StatelessWidget {
  const BluetoothView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocListener<BluetoothBloc, BluetoothState>(
      // Only an action the user asked for raises a notification, so a device
      // another client connected stays quiet.
      listenWhen: (previous, current) =>
          current.noticeMessage != null &&
          previous.noticeMessage != current.noticeMessage,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.noticeMessage!),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Scaffold(
        body: BlocBuilder<BluetoothBloc, BluetoothState>(
          builder: (context, state) {
            final isLoading = state.status == BluetoothStatus.loading;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bluetooth',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pair controllers, headsets, and input devices',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (state.isEnabled)
                        IconButton.filledTonal(
                          onPressed: () => context.read<BluetoothBloc>().add(
                            state.isDiscovering
                                ? const StopDiscoveryEvent()
                                : const StartDiscoveryEvent(),
                          ),
                          icon: state.isDiscovering
                              ? const Icon(Icons.stop_circle_outlined)
                              : const Icon(Icons.bluetooth_searching),
                          tooltip: state.isDiscovering
                              ? 'Stop scanning'
                              : 'Scan for devices',
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (state.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Error: ${state.errorMessage}',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),

                  if (isLoading && !state.isAvailable)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48.0),
                      child: Center(child: RdeLoadingIndicator()),
                    )
                  else if (state.status == BluetoothStatus.failure)
                    _buildMessage(
                      theme,
                      colorScheme,
                      'Bluetooth is unavailable on this system.',
                    )
                  else if (!state.isAvailable)
                    _buildMessage(
                      theme,
                      colorScheme,
                      'No Bluetooth adapter was found. Connect a controller '
                      'or check that the radio is not blocked by rfkill.',
                    )
                  else ...[
                    _buildAdapterCard(context, state),
                    const SizedBox(height: 16),
                    if (state.isEnabled) _buildDevicesCard(context, state),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Centered explanation shown when the page cannot list anything.
  Widget _buildMessage(ThemeData theme, ColorScheme colorScheme, String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// Radio controls and controller identity.
  Widget _buildAdapterCard(BuildContext context, BluetoothState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final adapter = state.adapter!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: state.isEnabled
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        state.isEnabled
                            ? Icons.bluetooth
                            : Icons.bluetooth_disabled,
                        color: state.isEnabled
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
                          adapter.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          state.isEnabled
                              ? (state.isDiscovering
                                    ? 'Scanning for devices…'
                                    : 'Ready • ${adapter.address}')
                              : 'Radio disabled',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: state.isEnabled,
                  onChanged: state.busyAddress != null
                      ? null
                      : (value) => context.read<BluetoothBloc>().add(
                          ToggleBluetoothPowerEvent(value),
                        ),
                ),
              ],
            ),
            if (state.isEnabled) ...[
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Discoverable',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          state.isDiscoverable
                              ? 'Other devices can find "${adapter.name}"'
                              : 'Hidden from other devices',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: state.isDiscoverable,
                    onChanged: (value) => context.read<BluetoothBloc>().add(
                      ToggleDiscoverableEvent(value),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Connected, paired, and newly discovered devices.
  Widget _buildDevicesCard(BuildContext context, BluetoothState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final sections = <(String, List<BluetoothDevice>)>[
      ('Connected', state.connectedDevices),
      ('Paired Devices', state.pairedDevices),
      ('Available Devices', state.availableDevices),
    ].where((section) => section.$2.isNotEmpty).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.devices_other, size: 20, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Devices',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (state.isDiscovering) const RdeLoadingIndicator(size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              state.isDiscovering
                  ? 'Looking for devices in range. Put the device in '
                        'pairing mode so it shows up.'
                  : 'Scanning is stopped. Start a scan to find devices in '
                        'range.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (sections.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Text(
                  'No devices yet. Start a scan and put the device you want '
                  'to pair with into pairing mode.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final section in sections) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    section.$1.toUpperCase(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      letterSpacing: 1.3,
                      fontSize: 10,
                    ),
                  ),
                ),
                for (final device in section.$2)
                  _buildDeviceTile(context, state, device),
              ],
          ],
        ),
      ),
    );
  }

  /// One device with its state and the actions that apply to it.
  Widget _buildDeviceTile(
    BuildContext context,
    BluetoothState state,
    BluetoothDevice device,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isBusy = state.busyAddress == device.address;

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
                    Icon(
                      _iconFor(device.icon),
                      size: 20,
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
                            _subtitleFor(device),
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
            Row(
              children: [
                if (device.connected)
                  TextButton(
                    onPressed: () => context.read<BluetoothBloc>().add(
                      DisconnectDeviceEvent(device.address),
                    ),
                    child: const Text('Disconnect'),
                  )
                else
                  TextButton(
                    onPressed: () => context.read<BluetoothBloc>().add(
                      ConnectDeviceEvent(device.address),
                    ),
                    child: Text(device.paired ? 'Connect' : 'Connect anyway'),
                  ),
                if (!device.paired)
                  TextButton(
                    onPressed: () => context.read<BluetoothBloc>().add(
                      PairDeviceEvent(device.address),
                    ),
                    child: const Text('Pair'),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'More actions',
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
                    const PopupMenuItem(value: 'forget', child: Text('Forget')),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Describes one device in the line under its name.
  String _subtitleFor(BluetoothDevice device) {
    final parts = <String>[
      device.address,
      if (device.batteryPercentage != null) '${device.batteryPercentage}%',
      if (device.rssi != null) '${device.rssi} dBm',
      if (device.paired) 'Paired',
      if (device.trusted) 'Trusted',
    ];
    return parts.join(' • ');
  }

  /// Maps the icon name BlueZ derives from the device class onto a Material one.
  IconData _iconFor(String? icon) {
    switch (icon) {
      case 'audio-headset':
        return Icons.headset;
      case 'audio-headphones':
        return Icons.headphones;
      case 'audio-card':
        return Icons.audio_file;
      case 'audio-speakers':
        return Icons.speaker;
      case 'input-keyboard':
        return Icons.keyboard;
      case 'input-mouse':
        return Icons.mouse;
      case 'input-gaming':
        return Icons.sports_esports;
      case 'input-tablet':
        return Icons.tablet;
      case 'input-touchpad':
        return Icons.touch_app;
      case 'phone':
        return Icons.smartphone;
      case 'computer':
        return Icons.computer;
      case 'printer':
        return Icons.print;
      case 'scanner':
        return Icons.scanner;
      case 'camera-photo':
        return Icons.photo_camera;
      case 'camera-video':
        return Icons.videocam;
      case 'video-display':
        return Icons.tv;
      case 'multimedia-player':
        return Icons.music_note;
      case 'modem':
        return Icons.router;
      default:
        return Icons.bluetooth;
    }
  }
}
