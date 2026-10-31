import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/core/widgets/rde_quick_action_tile.dart';
import 'package:rde_settings/core/widgets/rde_slider.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/volume_bloc.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/volume_event.dart';
import 'package:rde_settings/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:rde_settings/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:rde_settings/features/dashboard/presentation/bloc/dashboard_state.dart';

class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({super.key, required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final volumeState = context.watch<VolumeBloc>().state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Quick Actions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: RdeSlider(
                        min: 0,
                        max: 100,
                        value: state.brightness * 100,
                        divisions: 100,
                        label: "Brightness",
                        onChanged: (value) {},
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 40,
                      child: Text(
                        "${(state.brightness * 100).toInt()}%",
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: RdeSlider(
                        min: 0,
                        max: 100,
                        value: volumeState.master?.volume.toDouble() ?? 0,
                        divisions: 100,
                        label: "Volume",
                        onChanged: (value) {
                          context.read<VolumeBloc>().add(
                            VolumeSetEvent(value.round()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 40,
                      child: Text(
                        "${(volumeState.master?.volume.toDouble() ?? 0).toInt()}%",
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              spacing: 12,
              children: [
                RdeQuickActionTile(
                  icon: state.wifiEnabled ? Icons.wifi : Icons.wifi_off,
                  isActive: state.wifiEnabled,
                  onTap: () => context.read<DashboardBloc>().add(
                    ToggleWifiEvent(!state.wifiEnabled),
                  ),
                ),
                RdeQuickActionTile(
                  icon: state.bluetoothEnabled
                      ? Icons.bluetooth
                      : Icons.bluetooth_disabled,
                  isActive: state.bluetoothEnabled,
                  onTap: () => context.read<DashboardBloc>().add(
                    ToggleBluetoothEvent(!state.bluetoothEnabled),
                  ),
                ),
                RdeQuickActionTile(
                  icon: Icons.dark_mode,
                  isActive: false,
                  onTap: () {},
                ),
                RdeQuickActionTile(
                  icon: Icons.airplanemode_active,
                  isActive: false,
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
