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
                  spacing: 12,
                  children: [
                    Icon(
                      state.brightness <= 0.2
                          ? Icons.brightness_low_rounded
                          : state.brightness <= 70
                          ? Icons.brightness_medium_rounded
                          : Icons.brightness_high_rounded,
                      size: 30,
                    ),

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
                    Text(
                      "${(state.brightness * 100).toInt()}%",
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  spacing: 12,
                  children: [
                    Icon(
                      (volumeState.master?.volume ?? 0) == 0
                          ? Icons.volume_off_rounded
                          : (volumeState.master?.volume ?? 0) <= 70
                          ? Icons.volume_down_rounded
                          : Icons.volume_up_rounded,
                      size: 30,
                    ),
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

                    Text(
                      "${(volumeState.master?.volume.toDouble() ?? 0).toInt()}%",
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
                SizedBox(height: 16),
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
