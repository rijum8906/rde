import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:rde_settings/features/dashboard/domain/use_cases/get_dashboard_settings.dart';
import 'package:rde_settings/features/dashboard/domain/use_cases/save_dashboard_settings.dart';
import 'package:rde_settings/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:rde_settings/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:rde_settings/features/dashboard/presentation/bloc/dashboard_state.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Inject repository and use cases locally at the feature entry point
    final repository = DashboardRepositoryImpl();
    final getUseCase = GetDashboardSettingsUseCase(repository);
    final saveUseCase = SaveDashboardSettingsUseCase(repository);

    return BlocProvider(
      create: (context) => DashboardBloc(
        getSettingsUseCase: getUseCase,
        saveSettingsUseCase: saveUseCase,
      )..add(const DashboardInitEvent()),
      child: const DashboardView(),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state.status == DashboardStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == DashboardStatus.failure) {
            return Center(
              child: Text(
                'Failed to load settings: ${state.errorMessage}',
                style: TextStyle(color: colorScheme.error),
              ),
            );
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Title
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dashboard',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'System status and quick toggles',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Welcome banner with animated gradient background
                _buildWelcomeBanner(context),
                const SizedBox(height: 32),

                // Two-column layout on wide screens
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 800;
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildQuickTogglesSection(context, state),
                                const SizedBox(height: 32),
                                _buildSlidersSection(context, state),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildResourceHealthSection(context, state),
                                const SizedBox(height: 32),
                                _buildThemeCustomizerSection(context, state),
                              ],
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildQuickTogglesSection(context, state),
                          const SizedBox(height: 32),
                          _buildSlidersSection(context, state),
                          const SizedBox(height: 32),
                          _buildResourceHealthSection(context, state),
                          const SizedBox(height: 32),
                          _buildThemeCustomizerSection(context, state),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeBanner(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.tertiaryContainer.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Graphic abstract circle decorations
          Positioned(
            right: -40,
            top: -40,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -60,
            child: CircleAvatar(
              radius: 80,
              backgroundColor: colorScheme.tertiary.withValues(alpha: 0.15),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(
                            alpha: isDark ? 0.3 : 0.6,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Riju Desktop OS',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Welcome to your settings center',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Customize your display, network, inputs, and environment configurations dynamically.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Modern icon badge
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.15,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.desktop_mac_rounded,
                      size: 36,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTogglesSection(BuildContext context, DashboardState state) {
    final theme = Theme.of(context);

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
        LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 450;
            final wifiCard = _buildToggleCard(
              context: context,
              title: 'Wi-Fi Network',
              subtitle: state.wifiEnabled ? 'Connected to RDE-Net' : 'Off',
              icon: state.wifiEnabled ? Icons.wifi : Icons.wifi_off,
              value: state.wifiEnabled,
              onChanged: (val) {
                context.read<DashboardBloc>().add(ToggleWifiEvent(val));
              },
            );
            final btCard = _buildToggleCard(
              context: context,
              title: 'Bluetooth',
              subtitle: state.bluetoothEnabled ? 'Searching...' : 'Disabled',
              icon: state.bluetoothEnabled
                  ? Icons.bluetooth
                  : Icons.bluetooth_disabled,
              value: state.bluetoothEnabled,
              onChanged: (val) {
                context.read<DashboardBloc>().add(ToggleBluetoothEvent(val));
              },
            );

            if (isSmall) {
              return Column(
                children: [wifiCard, const SizedBox(height: 12), btCard],
              );
            } else {
              return Row(
                children: [
                  Expanded(child: wifiCard),
                  const SizedBox(width: 16),
                  Expanded(child: btCard),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildToggleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: value
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: value
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlidersSection(BuildContext context, DashboardState state) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hardware Adjustments',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSliderRow(
              context: context,
              label: 'Volume',
              value: state.volume,
              icon: state.volume == 0
                  ? Icons.volume_mute
                  : (state.volume < 0.5 ? Icons.volume_down : Icons.volume_up),
              onChanged: (val) {
                context.read<DashboardBloc>().add(ChangeVolumeEvent(val));
              },
            ),
            const Divider(height: 24),
            _buildSliderRow(
              context: context,
              label: 'Brightness',
              value: state.brightness,
              icon: Icons.light_mode,
              onChanged: (val) {
                context.read<DashboardBloc>().add(ChangeBrightnessEvent(val));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required BuildContext context,
    required String label,
    required double value,
    required IconData icon,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${(value * 100).toInt()}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Slider(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResourceHealthSection(
    BuildContext context,
    DashboardState state,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Health',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCircularGauge(
                  context: context,
                  label: 'CPU',
                  percentage: state.cpuUsage,
                  color: colorScheme.primary,
                ),
                _buildCircularGauge(
                  context: context,
                  label: 'RAM',
                  percentage: state.ramUsage,
                  color: colorScheme.secondary,
                ),
                _buildCircularGauge(
                  context: context,
                  label: 'Battery',
                  percentage: state.batteryLevel,
                  color: const Color(0xFF006E3C), // Emerald
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularGauge({
    required BuildContext context,
    required String label,
    required double percentage,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: percentage),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, val, _) {
        return Column(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: val,
                    strokeWidth: 6,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Text(
                      '${(val * 100).toInt()}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemeCustomizerSection(
    BuildContext context,
    DashboardState state,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final List<Color> accentColors = [
      const Color(0xFF6750A4), // Purple
      const Color(0xFF0061A4), // Ocean Blue
      const Color(0xFF006E3C), // Emerald
      const Color(0xFFB52700), // Terracotta
      const Color(0xFF7E5700), // Sunny Amber
      const Color(0xFFB90063), // Sunset Pink
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Personalization',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Theme Mode Segmented Controls
            Text(
              'Theme Mode',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.settings_suggest_outlined),
                ),
              ],
              selected: {state.themeMode},
              onSelectionChanged: (newSelection) {
                context.read<DashboardBloc>().add(
                  ChangeThemeModeEvent(newSelection.first),
                );
              },
            ),

            const SizedBox(height: 20),

            // Accent Color Selector
            Text(
              'Accent Color Seed',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: accentColors.map((color) {
                final isSelected = state.accentColor.value == color.value;
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      context.read<DashboardBloc>().add(
                        ChangeAccentColorEvent(color),
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              color: color.computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
