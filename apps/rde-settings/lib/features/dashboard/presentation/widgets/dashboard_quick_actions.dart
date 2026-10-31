import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core/theme.dart';
import 'package:rde_settings/core/widgets/rde_quick_action_tile.dart';
import 'package:rde_settings/core/widgets/rde_slider.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/volume_bloc.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/volume_event.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_event.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_bloc.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_bloc.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_event.dart';

/// Quick volume, brightness, and radio controls.
///
/// Each control reads the bloc that owns the service behind it, so a change
/// made on the dedicated page shows up here without a dashboard copy to keep
/// in sync. Brightness has no service bloc yet, so its slider keeps the value
/// locally.
class DashboardQuickActions extends StatefulWidget {
  const DashboardQuickActions({super.key});

  @override
  State<DashboardQuickActions> createState() => _DashboardQuickActionsState();
}

class _DashboardQuickActionsState extends State<DashboardQuickActions> {
  /// Brightness percentage shown by the slider.
  double _brightness = 0.65;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final volumeState = context.watch<VolumeBloc>().state;
    final wifiState = context.watch<WifiBloc>().state;
    final bluetoothState = context.watch<BluetoothBloc>().state;
    final themeState = context.watch<ThemeBloc>().state;
    final isDark = themeState.mode.isDark;

    return Card(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: Column(
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
                        IconButton.filledTonal(
                          onPressed: () {},
                          icon: Icon(
                            _brightness <= 0.2
                                ? Icons.brightness_low_rounded
                                : _brightness <= 0.7
                                ? Icons.brightness_medium_rounded
                                : Icons.brightness_high_rounded,
                            size: 30,
                          ),
                        ),

                        Expanded(
                          child: RdeSlider(
                            min: 0,
                            max: 100,
                            value: _brightness * 100,
                            divisions: 100,
                            label: "Brightness",
                            onChanged: (value) =>
                                setState(() => _brightness = value / 100),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          "${(_brightness * 100).toInt()}%",
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      spacing: 12,
                      children: [
                        IconButton.filledTonal(
                          onPressed: () => {},
                          icon: Icon(
                            (volumeState.master?.volume ?? 0) == 0
                                ? Icons.volume_off_rounded
                                : (volumeState.master?.volume ?? 0) <= 50
                                ? Icons.volume_down_rounded
                                : Icons.volume_up_rounded,
                            size: 30,
                          ),
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
                      icon: wifiState.isWifiEnabled
                          ? Icons.wifi
                          : Icons.wifi_off,
                      isActive: wifiState.isWifiEnabled,
                      onTap: () => context.read<WifiBloc>().add(
                        ToggleWifiRadioEvent(!wifiState.isWifiEnabled),
                      ),
                    ),
                    RdeQuickActionTile(
                      icon: bluetoothState.isEnabled
                          ? Icons.bluetooth
                          : Icons.bluetooth_disabled,
                      isActive: bluetoothState.isEnabled,
                      onTap: () {
                        // A machine without an adapter has nothing to switch.
                        if (!bluetoothState.isAvailable) return;
                        context.read<BluetoothBloc>().add(
                          ToggleBluetoothPowerEvent(!bluetoothState.isEnabled),
                        );
                      },
                    ),
                    RdeQuickActionTile(
                      icon: isDark ? Icons.dark_mode : Icons.light_mode,
                      isActive: isDark,
                      onTap: () => context.read<ThemeBloc>().add(
                        SetAppearanceEvent(
                          isDark ? AppearanceMode.light : AppearanceMode.dark,
                        ),
                      ),
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
        ),
      ),
    );
  }
}
