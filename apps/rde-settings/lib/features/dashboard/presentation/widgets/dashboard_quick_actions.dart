import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core/theme.dart';
import 'package:rde_settings/core/widgets/rde_quick_action_tile.dart';
import 'package:rde_settings/core/widgets/rde_slider.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/volume_bloc.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/volume_event.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_event.dart';
import 'package:rde_settings/features/display/presentation/bloc/brightness_bloc.dart';
import 'package:rde_settings/features/display/presentation/bloc/brightness_event.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_bloc.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_bloc.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_event.dart';

/// Quick volume, brightness, and radio controls.
///
/// Each control reads the bloc that owns the service behind it, so a change
/// made on the dedicated page shows up here without a dashboard copy to keep
/// in sync. Brightness is driven by `org.rde.Brightness` through
/// [BrightnessBloc].
class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final volumeState = context.watch<VolumeBloc>().state;
    final brightnessState = context.watch<BrightnessBloc>().state;
    final wifiState = context.watch<WifiBloc>().state;
    final bluetoothState = context.watch<BluetoothBloc>().state;
    final themeState = context.watch<ThemeBloc>().state;
    final isDark = themeState.mode.isDark;

    final brightness = brightnessState.level?.percent ?? 0;
    final brightnessReady =
        brightnessState.canChange && brightnessState.level != null;
    final brightnessText = brightnessState.isAvailable ? '$brightness%' : '—';
    final brightnessIcon = brightness <= 20
        ? Icons.brightness_low_rounded
        : brightness <= 70
        ? Icons.brightness_medium_rounded
        : Icons.brightness_high_rounded;

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
                          tooltip: 'Increase brightness',
                          onPressed: brightnessReady
                              ? () => context.read<BrightnessBloc>().add(
                                  const BrightnessIncreaseEvent(10),
                                )
                              : null,
                          icon: Icon(brightnessIcon, size: 30),
                        ),

                        Expanded(
                          child: RdeSlider(
                            min: 0,
                            max: 100,
                            value: brightness.toDouble().clamp(0, 100),
                            divisions: 100,
                            label: brightness
                                .toDouble()
                                .clamp(0, 100)
                                .round()
                                .toString(),
                            isEnabled: brightnessReady,
                            onChanged: brightnessReady
                                ? (value) => context.read<BrightnessBloc>().add(
                                    BrightnessSliderChangedEvent(value.round()),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(brightnessText, textAlign: TextAlign.right),
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
                            label: volumeState.master?.volume.toString(),
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
