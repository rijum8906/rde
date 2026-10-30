import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/bluetooth/data/datasources/dbus/bluez_proxy.dart';
import 'package:rde_settings/features/bluetooth/data/datasources/dbus_bluetooth_datasource.dart';
import 'package:rde_settings/features/bluetooth/domain/repositories/bluetooth_repository_impl.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_event.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_state.dart';
import 'package:rde_settings/features/bluetooth/presentation/widgets/bluetooth_adapter_card.dart';
import 'package:rde_settings/features/bluetooth/presentation/widgets/bluetooth_device_card.dart';
import 'package:rde_settings/features/bluetooth/presentation/widgets/bluetooth_error_banner.dart';
import 'package:rde_settings/features/bluetooth/presentation/widgets/bluetooth_error_message.dart';
import 'package:rde_settings/features/bluetooth/presentation/widgets/bluetooth_header.dart';
import 'package:rde_settings/features/bluetooth/presentation/pages/bluetooth_paired_page.dart';

/// Sections of the Bluetooth page.
enum BluetoothSection { devices, paired }

/// Bluetooth settings backed by `org.bluez`.
///
/// The page is a BlueZ client: bluetoothd owns the adapter and the device
/// tree, so every read and mutation goes through org.bluez.
class BluetoothPage extends StatelessWidget {
  const BluetoothPage({super.key});

  @override
  Widget build(BuildContext context) {
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

/// Renders the state published by [BluetoothBloc].
///
/// Owns the local section selector: which section the user is on is a page
/// concern, so the bloc does not track it.
class BluetoothView extends StatefulWidget {
  const BluetoothView({super.key});

  @override
  State<BluetoothView> createState() => _BluetoothViewState();
}

class _BluetoothViewState extends State<BluetoothView> {
  BluetoothSection _section = BluetoothSection.devices;

  @override
  Widget build(BuildContext context) {
    return BlocListener<BluetoothBloc, BluetoothState>(
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
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BluetoothHeader(),
                  const SizedBox(height: 20),
                  if (state.errorMessage != null) ...[
                    BluetoothErrorBanner(message: state.errorMessage!),
                    const SizedBox(height: 12),
                  ],
                  if (state.status == BluetoothStatus.loading &&
                      !state.isAvailable)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48.0),
                      child: Center(child: RdeLoadingIndicator()),
                    )
                  else if (state.status == BluetoothStatus.failure)
                    const BluetoothEmptyMessage(
                      text: 'Bluetooth is unavailable on this system.',
                    )
                  else if (!state.isAvailable)
                    const BluetoothEmptyMessage(
                      text:
                          'No Bluetooth adapter was found. Connect a controller '
                          'or check that the radio is not blocked by rfkill.',
                    )
                  else ...[
                    const BluetoothAdapterCard(),
                    const SizedBox(height: 16),
                    if (state.isEnabled) ...[
                      SegmentedButton<BluetoothSection>(
                        segments: const [
                          ButtonSegment(
                            value: BluetoothSection.devices,
                            icon: Icon(Icons.devices_other, size: 16),
                            label: Text('Devices'),
                          ),
                          ButtonSegment(
                            value: BluetoothSection.paired,
                            icon: Icon(Icons.bluetooth_connected, size: 16),
                            label: Text('Paired Devices'),
                          ),
                        ],
                        selected: {_section},
                        onSelectionChanged: (selection) =>
                            setState(() => _section = selection.first),
                        showSelectedIcon: false,
                      ),
                      const SizedBox(height: 16),
                      if (_section == BluetoothSection.devices)
                        const BluetoothDevicesCard()
                      else
                        const BluetoothPairedPage(),
                    ],
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
